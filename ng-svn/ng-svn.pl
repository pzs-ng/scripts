#!/usr/bin/perl -w
use strict;
use POE;
use Fcntl;
use POE::Component::IRC;
use HTTP::Date;
use Time::Duration;
use AnyDBM_File;

my $nick        = 'pzs-ng';
my $server      = 'irc.homelien.no:6667';
my @channels    = ('#project-zs-ng,pzsdev', '#pzs-ng');
my $realname    = 'p-zs-ng - SVN Slave.';
my $username    = 'pzs-ng';
my $polltime    = 5;
my $repository  = '/svn/pzs-ng';
my $factdb		= 'factoids';

my @fact_reply		= (
	q/$fact is $factoid, $nick./,
	q/$nick: '$fact' is '$factoid'/,
	q/$nick, $fact -> $factoid/,
	q/$nick, $fact is like, uh, $factoid, or something./,
	q/Definition of $fact is $factoid. D-uh./,
	q/$nick, I was told that $fact is $factoid. Cool, eh? :)/
);
my @fact_added		= (
	q/Sure, $nick!/,
	q/$nick, of course!/,
	q/Whatever you say!/,
	q/$nick: If that's your opinion!/,
	q/Yep, that's affirmative./,
	q/Okay, I'll remember about $fact :)/,
	q/Yeah, I knew that! *cough cough* *shuffle*/
);
my @fact_deleted	= (
	q/'tis already gone from my mind!/,
	q/Okay, I'll try my best to forget about $fact! :)/,
	q/Hmmm. What was that you said about $fact? ;-)/,
	q/I'll remove $fact from my memory ASAP!/
);
my @fact_unknown	= (
	q/Heh, $nick, I've never even HEARD about $fact!/,
	q/Eh. $fact, you say? Can't seem to remember, $nick, sorry./,
	q/$nick: Weeeell... You can't say $fact is common knowledge, atleast!/,
	q/Uh uh, $nick, I don't know anything about $fact!/,
	q/Whatyousay, $nick? $fact?/
);
	
# END #

my $started		= time;
my $youngest	= 0; 

our %factoids;
tie(%factoids, 'AnyDBM_File', $factdb, O_RDWR|O_CREAT, 0640);

sub _start {
    my $kernel = $_[KERNEL];
    $kernel->post('pzs-ng', 'register', 'all');
    $kernel->post('pzs-ng', 'connect',
              { Nick     => $nick,
                Server   => (split(/:/, $server))[0],
                Port     => (split(/:/, $server))[1],
                Username => $username,
                Ircname  => $realname, } );
    $kernel->delay('tick', 1);
}

sub _stop {
    my $kernel = $_[KERNEL];
    $kernel->call( 'pzs-ng', 'quit', 'Control session stopped.' );
}

sub irc_001 {
	my $kernel = $_[KERNEL];

	foreach my $chan (@channels) {
		my ($channel, $key) = split(',', $chan);
		if (defined($key)) { $kernel->post('pzs-ng', 'join', $channel, $key);
		} else { $kernel->post('pzs-ng', 'join', $channel); }
	}
	$kernel->post('pzs-ng', 'mode', $nick, '+i' );
}

sub irc_disconnected {
    my ($kernel, $server) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

sub irc_error {
    my ($kernel, $err) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

sub irc_socketerr {
    my ($kernel, $err) = @_[KERNEL, ARG0];
    $kernel->post('pzs-ng', 'shutdown'); exit 0;
}

sub irc_public {
	my ($kernel, $hostmask, $target, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
	$target = $target->[0];
	if ($target ne (split(',', $channels[0]))[0]) { return; }
	my $from = $hostmask; $from =~ s/^([^!]+)!.*$/$1/;
	if ($msg =~ /^$nick[,;:]\s+(\S+) (?:is|=) (.*)$/i) {
		my ($factoid, $def) = (lc($1), $2);
		$factoids{$factoid} = $def;
		my $reply = $fact_added[rand(scalar @fact_added)];
		$reply =~ s/\$nick/$from/g;
		$reply =~ s/\$me/$nick/g;
		$reply =~ s/\$fact/$factoid/g;
		$kernel->post('pzs-ng', 'privmsg', $target, $reply);
	} elsif ($msg =~ /^$nick[,;:]\s+(\S+) (?:isreg(?:ex(?:ed)?)?|is~|=~) s\/(.+)(?<!\\)\/(.*)\/(g?)$/i) {
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
				$reply =~ s/\$me/$nick/g;
				$reply =~ s/\$fact/$factoid/g;
			} else { $reply = "Invalid regex: $@"; }
			$kernel->post('pzs-ng', 'privmsg', $target, $reply);
		} else {
			my $reply = $fact_unknown[rand(scalar @fact_unknown)];
			$reply =~ s/\$nick/$from/g;
			$reply =~ s/\$me/$nick/g;
			$reply =~ s/\$fact/$factoid/g;
			$kernel->post('pzs-ng', 'privmsg', $target, $reply);
		}
	} elsif ($msg =~ /^$nick[,;:]\s+forget\s+about\s+(\S+)$/i) {
		my $factoid = lc($1);
		if (defined($factoids{$factoid})) {
			delete $factoids{$factoid};
			my $reply = $fact_deleted[rand(scalar @fact_deleted)];
			$reply =~ s/\$nick/$from/g;
			$reply =~ s/\$me/$nick/g;
			$reply =~ s/\$fact/$factoid/g;
			$kernel->post('pzs-ng', 'privmsg', $target, $reply);
		} else {
			my $reply = $fact_unknown[rand(scalar @fact_unknown)];
			$reply =~ s/\$nick/$from/g;
			$reply =~ s/\$me/$nick/g;
			$reply =~ s/\$fact/$factoid/g;
			$kernel->post('pzs-ng', 'privmsg', $target, $reply);
		}			
	} elsif ($msg =~ /^$nick[,;:]\s+([^\? ]+)(?:\s+([^\?]+))?\?*$/i) {
		my $factoid = lc($1);
		my $arg = $2;
		if ($factoid =~ /^uptime$/i) {
			my $uptime = time - $started;
			$kernel->post('pzs-ng', 'privmsg', $target, "$from, I have been running for ". duration($uptime) ." :)");
		} elsif ($factoid =~ /^(revision|rev)$/i) {
			$kernel->post('pzs-ng', 'privmsg', $target, "$from, latest revision of pzs-ng is $youngest.");
		} elsif ($factoid =~ /^(factstats?|stats?)$/i) {
			$kernel->post('pzs-ng', 'privmsg', $target, 
"$from, I know ". scalar keys(%factoids) ." different keywords, and their facts equal ". length(join('', values %factoids )) ." characters! :)"); 
		} elsif ($factoid =~ /^rinfo$/i) {
			my $revision = $arg;
			if (!defined($arg)) { $revision = $youngest; }
			if ($revision !~ /^\d+$/ || $revision > $youngest || $revision < 1) {
				$kernel->post('pzs-ng', 'privmsg', (split(',', $channels[0]))[0], "$from, r$revision is an invalid revision-number.");
			} else {
				my $output = `svnlook log -r $revision $repository`;
				my $author = `svnlook author -r $revision $repository`;
				my @dirs = split("\n", `svnlook dirs-changed -r $revision $repository`);
				my @files = split("\n", `svnlook changed -r $revision $repository|awk '{print \$2}'`);
				my (%changed, $chprefix);
				foreach my $dir (@dirs) {
					for my $i (0 .. $#files) {
						if ($files[$i] =~ /^$dir/) { 
							$files[$i] =~ s/^$dir//;
							push(@{$changed{$dir}}, $files[$i]);
							undef $files[$i];
						}
					}
				}
				$chprefix = '';
				foreach my $dir (keys %changed) {
					if (exists($changed{$dir}) && @{$changed{$dir}} == 1) { 
							(my $tmp = $dir) =~ s/^(.*?)trunk\///;
							$chprefix .= "$tmp" . $changed{$dir}[0];
					} else {
						(my $tmp = $dir) =~ s/^(.*?)trunk\///;
						$chprefix .= "$tmp: ";
						foreach my $file (@{$changed{$dir}}) {
							$chprefix .= "$file "
						}
						$chprefix =~ s/ $//;
					}
					$chprefix .= ', ';
				}
				$chprefix =~ s/, $//;

				$output =~ s/[\r\n]+/ /g; $author =~ s/[\r\n]+//g;
				$kernel->post('pzs-ng', 'privmsg', (split(',', $channels[0]))[0], "\00303$author\003 * r$revision $chprefix\002:\002 $output");
			}
		} else {
			if (defined($factoids{$factoid})) {
				my $def = $factoids{$factoid}; 
				if ($def =~ /^\$ (.*)$/) {
					$def = $1;
					$def =~ s/\$nick/$from/g;
					$def =~ s/\$me/$nick/g;
					$def =~ s/\$fact/$factoid/g;
					$kernel->post('pzs-ng', 'privmsg', $target, $def);
				} else {
					my $reply = $fact_reply[rand(scalar @fact_reply)];
					$reply =~ s/\$factoid/$def/g;
					$reply =~ s/\$nick/$from/g;
					$reply =~ s/\$me/$nick/g;
					$reply =~ s/\$fact/$factoid/g;
					$kernel->post('pzs-ng', 'privmsg', $target, $reply);
				}
			} else {
				my $reply = $fact_unknown[rand(scalar @fact_unknown)];
				$reply =~ s/\$nick/$from/g;
				$reply =~ s/\$me/$nick/g;
				$reply =~ s/\$fact/$factoid/g;
				$kernel->post('pzs-ng', 'privmsg', $target, $reply);
			}
		}
	}
}

sub irc_ctcp_version {
    my $target = $_[ARG0];
    $target =~ s/^([^!]+)!(?:.*)$/$1/;
    $_[KERNEL]->post('pzs-ng', 'ctcpreply', $target, "VERSION p-zs-ng\002v0.4-SVN\002 - (c) daxxar \002/\002 team pzs-ng");
}

sub tick {
	my $kernel = $_[KERNEL];
	my $ryoungest = `svnlook youngest $repository`;
	$ryoungest =~ s/[\r\n]+//g;
	if (!$youngest || $youngest > $ryoungest) { $youngest = $ryoungest; }
	elsif ($youngest != $ryoungest) {
		my $x = 0;
		while ($x < ($ryoungest - $youngest)) {
			$x++;
			my $revision = $youngest + $x;
			my $author = `svnlook author -r $revision $repository`;
			my @output = split("\n", `svnlook log -r $revision $repository`);;
			my @files = split("\n", `svnlook changed -r $revision $repository`);

			$author =~ s/[\r\n]+//g;
			foreach my $chan (@channels) {
				my $channel = (split(',', $chan))[0];
				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-------\003 SVNCOMMiT \00303-------\003");
				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303--\003 Author: $author Revision: $revision");
				foreach my $line (@output) {
					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303- $line");
				}

				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-----\003 CHANGED FiLES \00303-----\003");
				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303--\003 ". scalar @files ." file(s)");
				my $i = 0;
				foreach my $file (@files) {
					$i++;
					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-\003 $file");
					if ($i > 5 && @files >= $i + 2) { last; }
				}
				if ($i < @files) {
					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-\003 (". @files - $i ." file(s) not shown)");
				}
			}
		}
		$youngest = $ryoungest;
	}
		
    $kernel->delay('tick', $polltime);
}

my $pid = fork();
if (!defined($pid)) {
    print STDERR "Could not fork! $!\n";
    exit 1;
} elsif ($pid > 0) {
	open(PID, '>', 'ng-svn.pid'); print PID $pid; close(PID);
    print "Fork successful, child pid is $pid\n";
    exit 0;
}

POE::Component::IRC->new('pzs-ng') or die "Oh noooo! $!";
POE::Session->new( 'main' => [qw(_start _stop irc_001 irc_disconnected irc_error irc_socketerr irc_public irc_ctcp_version tick)]);
$poe_kernel->run();

untie %factoids;

exit 0;

# sussman adding a comment.  and another one.
