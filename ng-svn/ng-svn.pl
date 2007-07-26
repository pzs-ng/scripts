#!/usr/bin/perl -w
use strict;
use warnings;

use POE;
use POE::Component::IRC qw(PROGRAM);
use POE::Wheel::Run;

use HTTP::Date;
use Fcntl;
use Time::Duration;
use AnyDBM_File;
use File::Spec;
use YAML;

my $configFile = 'ng-svn.yaml';

my @fact_reply = (
    q/$fact is $factoid, $nick./,
    q/$nick: '$fact' is '$factoid'/,
    q/$nick, $fact -> $factoid/,
    q/$nick, $fact is like, uh, $factoid, or something./,
    q/Definition of $fact is $factoid. D-uh./,
    q/$nick, I was told that $fact is $factoid. Cool, eh? :)/
);
my @fact_added = (
    q/Sure, $nick!/,
    q/$nick, of course!/,
    q/Whatever you say!/,
    q/$nick: If that's your opinion!/,
    q/Yep, that's affirmative./,
    q/Okay, I'll remember about $fact :)/,
    q/Yeah, I knew that! *cough cough* *shuffle*/
);
my @fact_deleted = (
   q/'tis already gone from my mind!/,
   q/Okay, I'll try my best to forget about $fact! :)/,
   q/Hmmm. What was that you said about $fact? ;-)/,
   q/I'll remove $fact from my memory ASAP!/
);
my @fact_unknown = (
   q/Heh, $nick, I've never even HEARD about $fact!/,
   q/Eh. $fact, you say? Can't seem to remember, $nick, sorry./,
   q/$nick: Weeeell... You can't say $fact is common knowledge, atleast!/,
   q/Uh uh, $nick, I don't know anything about $fact!/,
   q/Whatyousay, $nick? $fact?/
);

# END #

my $config = YAML::LoadFile($configFile);

my $debug = 0;
my $started = time;
my %youngest;

our (%channelNicks, %channelNicksTemporary);

our %factoids;
tie(%factoids, 'AnyDBM_File', $config->{factsdb}, O_RDWR|O_CREAT, 0640);

sub dprint { print @_ if $debug; }

sub trim {
    my $string = shift;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    return $string;
}

sub get_readme_typestring {
    my ($option, $zsconfig) = @_;
    my $type = '';
    for ($zsconfig->{options}->{$option}->{type}) {
        $_ eq 'integer' && do {
            if (exists($zsconfig->{options}->{$option}->{valid_values})) {
                $type = join('|', @{$zsconfig->{options}->{$option}->{valid_values}});
            } else {
                $type = 'NUMBER';
            }
            last;
        };
        $_ eq 'boolean' && do { $type = 'TRUE|FALSE'; last; };
        $_ eq 'character' && do { $type = 'CHAR'; last; };
        $type = uc;
    }
    if (exists($zsconfig->{options}->{$option}->{can_disable})
            && $zsconfig->{options}->{$option}->{valid_values}) {
        $type .= '|DISABLED'
    }

    return $type;
}
sub get_readme_default {
    my ($option, $zsconfig) = @_;
    if ($zsconfig->{options}->{$option}->{type} eq 'boolean') {
        return ($zsconfig->{options}->{$option}->{default} =~ /^true$/i) ? 'TRUE' : 'FALSE';
    } else {
        return $zsconfig->{options}->{$option}->{default};
    }
}

sub _start {
    my ($kernel,$heap) = @_[KERNEL,HEAP];
    my $irc_session = $heap->{irc}->session_id();
    $kernel->post($irc_session => 'register' => 'all');
    $kernel->post($irc_session => 'connect' => {});
    $kernel->delay('tick', 1);
}

sub _stop {
    my $kernel = $_[KERNEL];
    $kernel->call( 'pzs-ng', 'quit', 'Control session stopped.' );
    exit 0;
}

### Handle SIGCHLD.  Shut down if the exiting child process was the
### one we've been managing.

sub sigchld {
    my ( $heap, $child_pid ) = @_[HEAP, ARG1];
    if ( $child_pid == $heap->{program}->PID ) {
        delete $heap->{program};
        delete $heap->{stdio};
    }
    return 0;
}

### Handle SIGUSR1.  Reload pzs-ng's config.yaml.

sub sigusr1 {
    my $heap = $_[HEAP];
    $heap->{zsconfig} = YAML::LoadFile($heap->{config}->{zsconfig});
    return 0;
}


### Handle STDOUT from the child program.
sub child_stdout {
    my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];
    my $target = $heap->{config}->{connection}->{adminchan};

    my $irc_session = $heap->{irc}->session_id();
    $kernel->post($irc_session => 'privmsg' => $target => "\00309$heap->{program}->[POE::Wheel::Run::PROGRAM()]\003: $input");
}

sub irc_001 {
    my ($kernel, $heap, $sender) = @_[KERNEL,HEAP,SENDER];

    foreach my $chan (@{$heap->{config}->{connection}->{channels}}) {
        my ($channel, $key) = split(',', $chan);
        if (defined($key)) { $kernel->post($sender => 'join' => $channel => $key);
        } else { $kernel->post($sender => 'join' => $channel); }
    }
    $kernel->post($sender => 'mode' => $heap->{config}->{connection}->{nick} => '+i');
}

# TODO: Fix this (not 'pzs-ng')
sub irc_disconnected {
    my ($kernel, $server) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

# TODO: Fix this (not 'pzs-ng')
sub irc_error {
    my ($kernel, $err) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

# TODO: Fix this (not 'pzs-ng')
sub irc_socketerr {
    my ($kernel, $err) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

#### OPLIST CODE ####
# These methods take care of having a list of nicks on each channel (incl. admin channel)
# irc_join also takes care of opping people who're in the admin channel.
sub is_on {
    my ($nick, $channel) = (shift, shift);
    dprint "Checking if $nick is on $channel.\n";

    if (ref $channelNicks{$channel} ne 'ARRAY')
    {
        dprint "$channel not an arrayref (". (ref $channelNicks{$channel}) .") :o\n";
        return  0;
    }
    return scalar grep {$_ eq $nick} @{$channelNicks{$channel}};
}
sub get_channels {
    my $nick = shift;
    return grep { is_on $nick, $_ } keys %channelNicks;
}
sub add_nick {
    my ($nick, $channel) = (shift, shift);
    dprint "Adding $nick to $channel.\n";
    push @{$channelNicks{$channel}}, $nick;
}
sub remove_nick {
    my ($nick, $channel) = (shift, shift);
    dprint "Removing $nick from $channel.\n";
    @{$channelNicks{$channel}} = grep {$_ ne $nick} @{$channelNicks{$channel}};
}

sub irc_join {
    my ($kernel, $heap, $sender, $hostmask, $chan) = @_[KERNEL, HEAP, SENDER, ARG0, ARG1];
    if ($hostmask =~ /^([^!]+)!/)
    {
        my $nick = $1;
        my $adminChan = $heap->{config}->{connection}->{adminchan};
        dprint "Got join: $nick -> $chan\n";
        if ($nick ne $heap->{config}->{connection}->{nick})
        {
            add_nick $nick, $chan;

# Checks wether or not someone is an admin, and if so; ops them where needed.
            if ($chan eq $adminChan)
            {
                for my $channel (get_channels $nick)
                {
                    dprint "Oping $nick on $channel.\n";
                    $kernel->post($sender => 'mode' => $channel => "+o $nick");
                }
            }
            elsif (is_on $nick, $adminChan)
            {
                dprint "Oping $nick on $chan.\n";
                $kernel->post($sender => 'mode' => $chan => "+o $nick");
            }
        }
    }
}
sub irc_kick {
    my ($kernel, $heap, $sender, $chan, $nick) = @_[KERNEL, HEAP, SENDER, ARG1, ARG2];

    dprint "Got kick: $nick -> $chan\n";
    if (is_on $nick, $chan)
    {
        remove_nick $nick, $chan;
    }

    my $adminChan = $heap->{config}->{connection}->{adminchan};
    if ($chan eq $adminChan)
    {
        dprint "Was admin, deoping in channels.\n";
        for my $channel (get_channels $nick)
        {
            $kernel->post($sender => 'mode' => $channel => "-o $nick");
        }
    }
}
sub irc_part {
    my ($kernel, $heap, $sender, $hostmask, $chan) = @_[KERNEL, HEAP, SENDER, ARG0, ARG1];

    if ($hostmask =~ /^([^!]+)!/)
    {
        my $nick = $1;
        dprint "Got part: $nick -> $chan\n";
        if (is_on $nick, $chan)
        {
            remove_nick $nick, $chan;
        }

        my $adminChan = $heap->{config}->{connection}->{adminchan};
        if ($chan eq $adminChan)
        {
            dprint "Was admin, deoping in channels.\n";
            for my $channel (get_channels $nick)
            {
                $kernel->post($sender => 'mode' => $channel => "-o $nick");
            }
        }
    }
}
sub irc_quit {
    my ($kernel, $hostmask) = @_[KERNEL, ARG0];

    if ($hostmask =~ /^([^!]+)!/)
    {
        my $nick = $1;
        dprint "Got quit: $nick\n";
        for my $channel (get_channels $nick)
        {
            remove_nick $nick, $channel;
        }
    }
}
sub irc_353 {
    my ($channel, $names) = split /:/, $_[ARG1];
    if ($channel =~ /([#&+]\S+)/)
    {
        $channel = $1;
        my @nicks = map { s/^[\@+\%]?//; $_ } split(/ +/, $names);
        dprint "Got NAMES-reply for $channel.\n";
        if (exists $channelNicksTemporary{$channel} && @{$channelNicksTemporary{$channel}})
        {
            dprint "Have temp, adding to it.\n";
            push @{$channelNicksTemporary{$channel}}, @nicks;
        }
        else
        {
            dprint "No temp, making new.\n";
            @{$channelNicksTemporary{$channel}} = @nicks;
        }
    }
}
sub irc_366 {
    my $channel = (split /:/, $_[ARG1])[0];
    if ($channel =~ /([#&+]\S+)/)
    {
        $channel = $1;
        dprint "Got NAMES-end for $channel.\n";
        if (exists $channelNicksTemporary{$channel} && @{$channelNicksTemporary{$channel}})
        {
            dprint "Had names, moving.\n";
            @{$channelNicks{$channel}} = @{$channelNicksTemporary{$channel}};
            delete $channelNicksTemporary{$channel};
        }
        else
        {
            @{$channelNicks{$channel}} = ();
        }
    }
}
### END OPLIST CODE ###

sub post_rinfo {
    my ($repository, $kernel, $sender, $target, $from, $data) = @_;
    my $revision;
    my $basename = +(File::Spec->splitdir($repository))[-1];

    if (!defined($data) || $data !~ /^r?(\d+)\s*$/)
    { $revision = $youngest{$repository};
    } else { $revision = $1; }

    if ($revision > $youngest{$repository} || $revision < 1) {
        $kernel->post($sender => 'privmsg' => $target => "$from, '$revision' is an invalid revision-number for $basename.");
    } else {
        dprint "post_rinfo: Checking $repository for changes in $revision.\n";
        my $output = `svnlook log -r $revision $repository`;
        my $author = `svnlook author -r $revision $repository`;
        my @dirs = split("\n", `svnlook dirs-changed -r $revision $repository`);
        my @files = split("\n", `svnlook changed -r $revision $repository|awk '{print \$2}'`);
        my (%changed, $chprefix);
        foreach my $dir (@dirs) {
            if (!@files) { last; }
            foreach my $file (@files) {
                if (defined($file) && $file =~ /^$dir/) {
                    $file =~ s/^$dir//;
                    push(@{$changed{$dir}}, $file);
                    undef $file;
                }
            }
        }
        $chprefix = '';
        foreach my $dir (keys %changed) {
            if (exists($changed{$dir}) && @{$changed{$dir}} == 1) {
                (my $tmp = $dir) =~ s/^(.*?)trunk//;
                $chprefix .= "\002$tmp\002" . $changed{$dir}[0];
            } else {
                (my $tmp = $dir) =~ s/^(.*?)trunk//;
                $chprefix .= "\002$tmp\002: ";
                foreach my $file (@{$changed{$dir}}) {
                    $chprefix .= "$file "
                }
                $chprefix =~ s/ $//;
            }
            $chprefix .= ', ';
        }
        $chprefix =~ s/, $//;

        $output =~ s/[\r\n]+/ /g; $author =~ s/[\r\n]+//g;
        $kernel->post($sender => 'privmsg' => $target => "$basename \00303$author\003 * r$revision $chprefix\002:\002 $output");
    }
}

sub irc_public {
    my ($kernel, $heap, $sender, $hostmask, $target, $msg) = @_[KERNEL, HEAP, SENDER, ARG0, ARG1, ARG2];
    $target = $target->[0];
    my $from = $hostmask; $from =~ s/^([^!]+)!.*$/$1/;
    if ($msg !~ /^$heap->{config}->{connection}->{nick} [,;:] \s+ (\w+) \s* (.*)/ix)
    {
        return;
    }
    my ($command, $data) = (lc($1), trim($2));
    my $admin = ($target eq $heap->{config}->{connection}->{adminchan});

    if ($command eq 'help' || $command eq 'commands' || $command eq 'cmds') {
        $kernel->post($sender => 'privmsg' => $target => " * \00309ng-svn.pl\003 commands:");
        $kernel->post($sender => 'privmsg' => $target => "\00309remember\003 <factoid name> <factoid>: Adds a new factoid with name <factoid name> and content <factoid> to the database. Do \00309help_remember\003 for specific syntax.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309help_remember\003: Shows specific syntax for factoids.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309edit\003 <factoid name> s/<search>/<replace>/[g]': Replaces <search> with <replace> in <factoid name>, 'g' means 'replace all'. (Uses regular expressions)") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309forget\003 <factoid name>: Deletes the factoid <factoid name> from the database.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309<factoid>\003: Shows added factoid with name <factoid>.");
        $kernel->post($sender => 'privmsg' => $target => "\00309config\003|\00309conf\003 <pattern>: Search for configuration options that match <pattern>");
        $kernel->post($sender => 'privmsg' => $target => "\00309release\003 <revision> <stable|testing|unstable|volatile> [release name]: Creates a new release from revision <revision>, and tags it as <stable|...>. Optionally takes a release-name, like 'v1.0.3' or 'beta3'. You need to \00309sync\003 to make this effective.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309invalidate\003 <revision> <stable|testing|unstable|volatile>: Invalidates (deletes) the specified <revision> from the tag <stable|...>. You need to \00309sync\003 to make this effective.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309list\003 <stable|testing|unstable|volatile>: Lists all released revisions (and their release names) in tag <stable|...>.");
        $kernel->post($sender => 'privmsg' => $target => "\00309sync\003 [wipe] <mirrors>: Synchronizes changes to HTML and releases to mirrors. 'wipe' means delete data before uploading (Corrupted uploads, e.g.). <mirrors> is a list of mirrors, space separated, country-code based.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309addquote\003 <quote>: Adds <quote> to the quote db. Can be fetched via IRC and is put onto web. You need to \00309sync\003 to make this effective.");
        $kernel->post($sender => 'privmsg' => $target => "\00309appendquote\003 <quote id> <text>: Appends <text> to an existant quote with <quote id> as its id. You need to \00309sync\003 to make this effective.");
        $kernel->post($sender => 'privmsg' => $target => "\00309delquote\003 <quote id>: Deletes quote with <quote id> as its id.") if $admin;
        $kernel->post($sender => 'privmsg' => $target => "\00309getquote\003 <quote id>: Shows quote with id <quote id>.");
        $kernel->post($sender => 'privmsg' => $target => "\00309rinfo\003 [revision]: Shows commit info on [revision], or lastest revision.");
        $kernel->post($sender => 'privmsg' => $target => "\00309uptime\003 - \00309stats\003 - \00309revision\003: Shows current uptime, factoid statistics or revision number, respectively.");
    } elsif ($command eq 'help_remember') {
        $kernel->post($sender => 'privmsg' => $target => " * \00309ng-svn.pl\003 factoid syntax:");
        $kernel->post($sender => 'privmsg' => $target => "Special variables: \00309\$nick\003 - \00309\$me\003 - \00309\$fact\003 = nick who requested factoid, bots nick and factoids name, respectively.");
        $kernel->post($sender => 'privmsg' => $target => "Special syntax: Prefix a factoid message with '\00309\$ \003' (has to be a space between \$ and the rest of the message) - Everything will be sent as is, no 'smart formatting or nick-prefixing.");
    } elsif ($command eq 'remember') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^(\S+)\s+(.*)$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, remember <factoid name> <factoid>'. Do help_remember for specific syntax.");
            return;
        }
        my ($factoid, $def) = (lc($1), $2);
        $factoids{$factoid} = $def;
        my $reply = $fact_added[rand(scalar @fact_added)];
        $reply =~ s/\$nick/$from/g;
        $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
        $reply =~ s/\$fact/$factoid/g;
        $kernel->post($sender => 'privmsg' => $target => $reply);
    } elsif ($command eq 'edit') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^(\S+) s\/(.+)(?<!\\)\/(.*)\/(g?)$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, edit <factoid name> s/<search>/<replace>/[g]'. 'g' means 'replace all'.");
            return;
        }
        my ($factoid, $match, $rep, $flags) = ($1, $2, $3, $4);
        if (defined($factoids{$factoid})) {
            $rep =~ s/\\\//\//g;
            $match =~ s/\\\//\//g;
            eval {
                $factoids{$factoid} =~ s/$match/$rep/g if $flags eq 'g';
                $factoids{$factoid} =~ s/$match/$rep/  unless $flags eq 'g';
            };
            my $reply;
            if (!$@) {
                $reply = $fact_added[rand(scalar @fact_added)];
                $reply =~ s/\$nick/$from/g;
                $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
                $reply =~ s/\$fact/$factoid/g;
            } else { $reply = "Invalid regex: $@"; }
            $kernel->post($sender => 'privmsg' => $target => $reply);
        } else {
            my $reply = $fact_unknown[rand(scalar @fact_unknown)];
            $reply =~ s/\$nick/$from/g;
            $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
            $reply =~ s/\$fact/$factoid/g;
            $kernel->post($sender => 'privmsg' => $target => $reply);
        }
    } elsif ($command eq 'forget') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^(\S+)\s*$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, forget <factoid name>.");
            return;
        }
        my $factoid = lc($1);
        if (defined($factoids{$factoid})) {
            delete $factoids{$factoid};
            my $reply = $fact_deleted[rand(scalar @fact_deleted)];
            $reply =~ s/\$nick/$from/g;
            $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
            $reply =~ s/\$fact/$factoid/g;
            $kernel->post($sender => 'privmsg' => $target => $reply);
        } else {
            my $reply = $fact_unknown[rand(scalar @fact_unknown)];
            $reply =~ s/\$nick/$from/g;
            $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
            $reply =~ s/\$fact/$factoid/g;
            $kernel->post($sender => 'privmsg' => $target => $reply);
        }
    } elsif ($command eq 'release') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^r?(\d+)\s+(stable|testing|unstable|volatile)(?:\s+(\S+))?$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, release <revision> <stable|testing|unstable|volatile> [release name]'.");
            return;
        }
        chdir($heap->{config}->{template_mirror_path});
        open(MAKE_TARBALL, "./make_tarball.sh $1 $2 $3|") if defined($3);
        open(MAKE_TARBALL, "./make_tarball.sh $1 $2|") if not defined($3);
        $kernel->post($sender => 'privmsg' => $target => "\00309make_tarball.sh\003 * $_") while (<MAKE_TARBALL>);
        close(MAKE_TARBALL);
    } elsif ($command eq 'sync') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        my $time = time();
        chdir($heap->{config}->{template_mirror_path});
        $heap->{program} = POE::Wheel::Run->new (
                Program => './tm.pl',
                ProgramArgs => [split(/ /, $data)],
                StdoutEvent => "child_stdout",
                StdoutFilter => POE::Filter::Line->new()
                );
    } elsif ($command eq 'invalidate') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^r?(\d+)\s+(stable|testing|unstable|volatile)$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, invalidate <revision> <stable|testing|unstable|volatile>'.");
            return;
        }
        my ($revision, $type) = ($1, $2);
        chdir($heap->{config}->{template_mirror_path});
        my @files = glob("files/$type/r${revision}_pzs-ng*.tar.gz");
        if (!@files) {
            $kernel->post($sender => 'privmsg' => $target => "$from, heh, r$revision isn't $type, so can't really change it ;)");
        } else {
            unlink(shift @files);
            $kernel->post($sender => 'privmsg' => $target => "$from, r$revision isn't $type any more. ;)");
        }
    } elsif ($command eq 'list') {
        if (!defined($data) || $data !~ /^(stable|testing|unstable|volatile)\s*$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, list <stable|testing|unstable|volatile>'.");
            return;
        }

        my $type = $1;
        my (@revisions, %revinfo);
        chdir($heap->{config}->{template_mirror_path});
        opendir(FILES, "files/$type");
        while ((my $entry = readdir(FILES))) {
            if (! -f "files/$type/$entry") { next; }
            if ($entry !~ /^project-zs-ng_r(\d+)(-(.+?))?\.tar\.gz$/) { next; }
            push(@revisions, $1);
            if (defined($3)) { $revinfo{$1} = $3 };
        }
        closedir(FILES);

        if (!@revisions) {
            $kernel->post($sender => 'privmsg' => $target => "$from, no files are marked as $type.");
        } else {
            my @tmprevisions;
            foreach my $revision (sort {$a <=> $b} @revisions) {
                push (@tmprevisions, "$revision" . (exists($revinfo{$revision}) ? " ($revinfo{$revision})" : ''));
                if (@tmprevisions >= 5) {
                    $kernel->post($sender => 'privmsg' => $target => "\00309$type\003 * " . join(', ', @tmprevisions) .".");
                    undef @tmprevisions;
                }
            }

            if (@tmprevisions) {
                $kernel->post($sender => 'privmsg' => $target => "\00309$type\003 * " . join(', ', @tmprevisions) .".");
            }
        }
    } elsif ($command eq 'addquote') {
        if (!defined($data) || $data =~ /^\s*$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, addquote <quote>'.");
            return;
        }

        open(QUOTES, ">>$heap->{config}->{quotesfile}");
        print QUOTES $data ."\n";
        close(QUOTES);
        open(QUOTES, $heap->{config}->{quotesfile});
        my $lines = 0; $lines++ while <QUOTES>;
        close(QUOTES);
        $kernel->post($sender => 'privmsg' => $target => "$from, added as quote #\002$lines\002!");
    } elsif ($command eq 'appendquote') {
        if (!defined($data) || $data !~ /^(\d+)\s+(.*)$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, appendquote <quoteid> <data to add>'.");
            return;
        }

        my ($qid, $quote) = ($1, $2);
        my @lines;

        open(QUOTES, $heap->{config}->{quotesfile});
        while (<QUOTES>) {
            chomp;
            push(@lines, $_) if $. != $qid;
            push(@lines, $_ . '\n' . $quote) if $. == $qid;
        }
        my $quotecount = $.;
        close(QUOTES);

        if ($quote > $quotecount) {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid quoteid!");
        } else {
            open(QUOTES, ">$heap->{config}->{quotesfile}");
            for my $quote (@lines) {
                print QUOTES "$quote\n";
            }
            close(QUOTES);
            $kernel->post($sender => 'privmsg' => $target => "$from, added to quote #\002$qid\002");
        }
    } elsif ($command eq 'delquote') {
        if ($target ne $heap->{config}->{connection}->{adminchan}) { return; }

        if (!defined($data) || $data !~ /^(\d+)\s*$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, delquote <quoteid>'.");
            return;
        }
        my $quote = $1;
        my @lines;

        open(QUOTES, $heap->{config}->{quotesfile});
        while (<QUOTES>) {
            push(@lines, $_) if $. != $quote;
        }
        my $quotecount = $.;
        close(QUOTES);

        if ($quote > $quotecount) {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid quoteid!");
        } else {
            close(QUOTES);
            open(QUOTES, ">$heap->{config}->{quotesfile}");
            for my $quote (@lines) {
                print QUOTES $quote;
            }
            $kernel->post($sender => 'privmsg' => $target => "$from, removed quote #\002$quote\002");
        }
    } elsif ($command eq 'quote' || $command eq 'getquote' || $command eq 'showquote') {
        if (!defined($data) || $data !~ /^(\d+)\s*$/)
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, getquote <quoteid>'.");
            return;
        }
        my $quote = $1;
        my @lines;

        open(QUOTES, $heap->{config}->{quotesfile});
        while (<QUOTES>) {
            if ($. == $quote) {
                for my $line (split(/\\n/, $_)) {
                    $kernel->post($sender => 'privmsg' => $target => "$from, #\002$quote\002: $line");
                }
            }
        }
        $kernel->post($sender => 'privmsg' => $target => "$from, invalid quoteid!") if $quote > $.;
        close(QUOTES);
    } elsif ($command eq 'uptime') {
        my $uptime = time - $started;
        $kernel->post($sender => 'privmsg' => $target => "$from, I have been running for ". duration($uptime) ." :)");
    } elsif ($command eq 'revision' || $command eq 'rev') {
        $kernel->post($sender => 'privmsg' => $target => "$from, latest revision of pzs-ng is ". $youngest{'/svn/pzs-ng'} .".");
    } elsif ($command eq 'stats') {
        $kernel->post($sender => 'privmsg' => $target => "$from, I know ". scalar keys(%factoids) ." different keywords, and their facts equal ". length(join('', values %factoids )) ." characters! :)");
    } elsif ($command eq 'config' || $command eq 'conf') {
        if (!defined($data))
        {
            $kernel->post($sender => 'privmsg' => $target => "$from, invalid syntax; valid syntax is: '$heap->{config}->{connection}->{nick}, config <pattern>'.");
            return;
        }
        $data =~ s/[^\w?*\-]+//g;
        $data =~ s/\*/.*/g;
        $data =~ s/\?/./g;
        my $options = "\002" . join("\002, \002", grep(/.*$data.*/i, keys %{$heap->{zsconfig}->{options}})) . "\002";
        $kernel->post($sender => 'privmsg' => $target => "$from, found; " . $options);
    } elsif ($command eq 'rinfo') {
        post_rinfo('/svn/pzs-ng', $kernel, $sender, $target, $from, $data);
    } elsif ($command eq 'rinfopp') {
        post_rinfo('/svn/zspp', $kernel, $sender, $target, $from, $data);
    } elsif ($msg =~ /^$heap->{config}->{connection}->{nick} [,;:] \s* ([^\? ]+) \s* ([^\?]+)? \?*$/ix) {
        my $factoid = lc($1);
        my $arg = trim($2);
        if (defined($factoids{$factoid})) {
            my $def = $factoids{$factoid};
            if ($def =~ /^\$ (.*)$/) {
                $def = $1;
                $def =~ s/\$nick/$from/g;
                $def =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
                $def =~ s/\$fact/$factoid/g;
                $kernel->post($sender => 'privmsg' => $target => $def);
            } else {
                my $reply = $fact_reply[rand(scalar @fact_reply)];
                $reply =~ s/\$factoid/$def/g;
                $reply =~ s/\$nick/$arg || $from/ge;
                $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
                $reply =~ s/\$fact/$factoid/g;
                $kernel->post($sender => 'privmsg' => $target => $reply);
            }
        } else {
            my @config = grep(/^$factoid$/i, keys %{$heap->{zsconfig}->{options}});
            if (@config) {
                for my $key (@config) {
                    my $message = "\002$key\002 <" . get_readme_typestring($key, $heap->{zsconfig});
                    $message .= " = \002". get_readme_default($key, $heap->{zsconfig}) ."\002> ";
                    $message .= join(' ', split(/[\r\n]+/, $heap->{zsconfig}->{options}->{$key}->{comment}));
                    $kernel->post($sender => 'privmsg' => $target => ($arg || $from) . ': ' . $message);
                }
            } else {
                my $reply = $fact_unknown[rand(scalar @fact_unknown)];
                $reply =~ s/\$nick/$from/g;
                $reply =~ s/\$me/$heap->{config}->{connection}->{nick}/g;
                $reply =~ s/\$fact/$factoid/g;
                $kernel->post($sender => 'privmsg' => $target => $reply);
            }
        }
    }
}

sub irc_ctcp_version {
    my ($target, $sender, $kernel) = @_[ARG0, SENDER, KERNEL];
    $target =~ s/^([^!]+)!(?:.*)$/$1/;
    $kernel->post($sender => 'ctcpreply' => $target => "VERSION p-zs-ng\002v0.99-SVN\002 - (c) daxxar \002/\002 team pzs-ng");
}

sub tick {
    my ($kernel, $heap) = @_[KERNEL, HEAP];
    my $irc_session = $heap->{irc}->session_id();
    my %repositories = %{$heap->{config}->{svn}->{repositories}};
    for my $repository (keys %repositories)
    {
        dprint "tick: Checking $repository for most recent revision.\n";
        my $ryoungest = `svnlook youngest $repository`;
        $ryoungest =~ s/[\r\n]+//g;
        if (!exists $youngest{$repository} || !$youngest{$repository} || $youngest{$repository} > $ryoungest)
        { $youngest{$repository} = $ryoungest; }

        elsif ($youngest{$repository} != $ryoungest) {
            my $x = 0;
            while ($x < ($ryoungest - $youngest{$repository})) {
                $x++;
                my $revision = $youngest{$repository} + $x;
                dprint "post_rinfo: Checking $repository for $revision.";
                my $author = `svnlook author -r $revision $repository`;
                my @output = split("\n", `svnlook log -r $revision $repository`);
                my @files = split("\n", `svnlook changed -r $revision $repository|awk '{print \$2}'`);
#			my @files = split("\n", `svnlook changed -r $revision $repository`);
                foreach my $file (@files) {
                    $file =~ s/^(.*?)trunk\///;
                    if ($file =~ /^\s*$/) { $file = '/'; }
                }
                my $filemsg = join(", ", @files);
                my $basename = +(File::Spec->splitdir($repository))[-1];

                $author =~ s/[\r\n]+//g;
                foreach my $channel (@{$repositories{$repository}}) {
                    my $commitmsgs = join("\002' & '\002", @output);
                    $commitmsgs = "'\002" . $commitmsgs . "\002'";

                    $kernel->post($irc_session => 'privmsg' => $channel => "$basename \00303svn\003 commit by \00303$author\003 \002*\002 r\002$revision\002: $commitmsgs");
                    $kernel->post($irc_session => 'privmsg' => $channel => "$basename \00303svn\003 files: $filemsg");
                }
            }
            $youngest{$repository} = $ryoungest;
        }
    }

    $kernel->delay('tick', $heap->{config}->{svn}->{polltime});
}

if (!$debug)
{
    my $pid = fork();
    if (!defined($pid)) {
        print STDERR "Could not fork! $!\n";
        exit 1;
    } elsif ($pid > 0) {
        open(PID, '>', 'ng-svn.pid'); print PID $pid; close(PID);
        print "Fork successful, child pid is $pid\n";
        close(STDOUT);
        exit 0;
    }
}

my $conn = $config->{connection}; # Just a shorthand for $irc definition.
my $irc = POE::Component::IRC->spawn(
        nick     => $conn->{nick},
        server   => (split(/:/, $conn->{server}))[0],
        port     => (split(/:/, $conn->{server}))[1],
        username => $conn->{username},
        localAddr=> $conn->{localaddr},
        ircname  => $conn->{realname}
        ) or die "Oh noooo! $!";

POE::Session->create(
        package_states => [
            'main' => [
                qw(_start _stop irc_001 irc_disconnected irc_error
                irc_socketerr irc_public irc_ctcp_version tick child_stdout
                sigchld irc_join irc_part irc_kick irc_quit irc_353 irc_366
                sigusr1)
            ]
        ], 'heap' => {
            irc => $irc,
            zsconfig => YAML::LoadFile($config->{zsconfig}),
            config => $config }
        );

$poe_kernel->sig(USR1 => "sigusr1");
$poe_kernel->sig(CHLD => "sigchld");
$poe_kernel->run();

untie %factoids;

exit 0;
