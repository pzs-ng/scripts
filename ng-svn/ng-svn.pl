#!/usr/bin/perl -w
use strict;

use POE;
use POE::Component::IRC qw(PROGRAM);
use POE::Wheel::Run;

use HTTP::Date;
use Fcntl;
use Time::Duration;
use AnyDBM_File;
use Data::Dumper;

my $nick        = 'pzs-ng';
my $server      = 'irc.homelien.no:6667';
my @channels    = ('#project-zs-ng,whydoyoucare', '#pzs-ng');
my $realname    = 'p-zs-ng - SVN Slave.';
my $username    = 'pzs-ng';
my $polltime    = 5;
my $repository  = '/svn/pzs-ng';
my $localaddr	= '192.168.0.11';
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
		LocalAddr=> $localaddr,
                Ircname  => $realname, } );
    $kernel->delay('tick', 1);
}

sub _stop {
    my $kernel = $_[KERNEL];
    $kernel->call( 'pzs-ng', 'quit', 'Control session stopped.' );
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

### Handle STDOUT from the child program.
sub child_stdout {
	my ($kernel, $heap, $input) = @_[KERNEL, HEAP, ARG0];
	my $target = (split(',', $channels[0]))[0];

	$kernel->post('pzs-ng', 'privmsg', $target, "\00309$heap->{program}->[POE::Wheel::Run::PROGRAM()]\003: $input");
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
	my ($kernel, $heap, $hostmask, $target, $msg) = @_[KERNEL, HEAP, ARG0, ARG1, ARG2];
	$target = $target->[0];
	my $from = $hostmask; $from =~ s/^([^!]+)!.*$/$1/;
	if ($msg =~ /^$nick[,;:]\s+(\S+) (?:is|=) (.*)$/i) {
		if ($target ne (split(',', $channels[0]))[0]) { return; }
		my ($factoid, $def) = (lc($1), $2);
		$factoids{$factoid} = $def;
		my $reply = $fact_added[rand(scalar @fact_added)];
		$reply =~ s/\$nick/$from/g;
		$reply =~ s/\$me/$nick/g;
		$reply =~ s/\$fact/$factoid/g;
		$kernel->post('pzs-ng', 'privmsg', $target, $reply);
	} elsif ($msg =~ /^$nick[,;:]\s+(\S+) (?:isreg(?:ex(?:ed)?)?|is~|=~) s\/(.+)(?<!\\)\/(.*)\/(g?)$/i) {
		if ($target ne (split(',', $channels[0]))[0]) { return; }
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
		if ($target ne (split(',', $channels[0]))[0]) { return; }
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
	} elsif ($msg =~ /^$nick[,;:]\s+make\s+r?(\d+)\s+(stable|testing|unstable)[.!]?$/) {
		if ($target ne (split(',', $channels[0]))[0]) { return; }
		chdir("/www/scripts/template-mirror/");
		open(MAKE_TARBALL, "./make_tarball.sh $1 $2|");
		while (<MAKE_TARBALL>) {
			$kernel->post('pzs-ng', 'privmsg', $target, "\00309make_tarball.sh\003 * $_");
		}
		close(MAKE_TARBALL);
	} elsif ($msg =~ /^$nick[,;:]\s+test[.!? ]*$/i) {
		$kernel->post('pzs-ng', 'privmsg', $target, "\00309test\003 * This should come instantly (but probably doesn't. fuck me hard)");
		sleep(10);
	} elsif ($msg =~ /^$nick[,;:]\s+sync(.*?)[.!]?$/) {
		if ($target ne (split(',', $channels[0]))[0]) { return; }
		my $time = time();
		chdir("/www/scripts/template-mirror/");
		$heap->{program} = POE::Wheel::Run->new (
			Program => './tm.pl',
			ProgramArgs => [split(/ /, $1)],
			StdoutEvent => "child_stdout",
			StdoutFilter => POE::Filter::Line->new()
		);
	} elsif ($msg =~ /^$nick[,;:]\s+r?(\d+)\s+(is no longer|is not|isn't|isnt|ain't)\s+(stable|testing|unstable)[.!]?$/) {
		if ($target ne (split(',', $channels[0]))[0]) { return; }
		my ($revision, $type) = ($1, $3);
		chdir("/www/scripts/template-mirror/");
		if (! -f "files/$type/r${revision}_pzs-ng.tar.gz") {
			$kernel->post('pzs-ng', 'privmsg', $target, "$from, heh, r$revision isn't $type, so can't really change it ;)");
		} else {
			unlink("files/$type/r${revision}_pzs-ng.tar.gz");
			$kernel->post('pzs-ng', 'privmsg', $target, "$from, r$revision isn't $type any more. ;)");
		}
	} elsif ($msg =~ /^$nick[,;:]\s+files\s+(in|who are|which are|whom are)\s+(stable|testing|unstable)\??\s*$/) {
		my $type = $2;
		my (@revisions, %revinfo);
		chdir("/www/scripts/template-mirror/");
		opendir(FILES, "files/$type");
		while ((my $entry = readdir(FILES))) {
			if (! -f "files/$type/$entry") { next; }
			if ($entry !~ /^r(\d+)_pzs-ng(-([^.]+))?\.tar\.gz$/) { next; }
			push(@revisions, $1);
			if (defined($3)) { $revinfo{$1} = $3 };
		}
		closedir(FILES);

		if (!@revisions) {
			$kernel->post('pzs-ng', 'privmsg', $target, "$from, no files are marked as $type.");
		} else {
			my @tmprevisions;
			foreach my $revision (sort {$a <=> $b} @revisions) {
				push (@tmprevisions, "$revision" . (exists($revinfo{$revision}) ? " ($revinfo{$revision})" : ''));
				if (@tmprevisions >= 5) {
					$kernel->post('pzs-ng', 'privmsg', $target, "\00309$type\003 * " . join(', ', @tmprevisions) .".");
					undef @tmprevisions;
				}
			}

			if (@tmprevisions) {
				$kernel->post('pzs-ng', 'privmsg', $target, "\00309$type\003 * " . join(', ', @tmprevisions) .".");
			}
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
		} elsif ($factoid =~ /^(rinfo|info)$/i) {
			my $revision = $arg;
			if (!defined($arg)) { $revision = $youngest; }
			if ($revision !~ /^\d+$/ || $revision > $youngest || $revision < 1) {
				$kernel->post('pzs-ng', 'privmsg', $target, "$from, '$revision' is an invalid revision-number.");
			} else {
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
				$kernel->post('pzs-ng', 'privmsg', $target, "\00303$author\003 * r$revision $chprefix\002:\002 $output");
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
			my @output = split("\n", `svnlook log -r $revision $repository`);
			my @files = split("\n", `svnlook changed -r $revision $repository|awk '{print \$2}'`);
#			my @files = split("\n", `svnlook changed -r $revision $repository`);
			foreach my $file (@files) {
				$file =~ s/^(.*?)trunk\///;
				if ($file =~ /^\s*$/) { $file = '/'; }
			}
			my $filemsg = join(", ", @files);
				

			$author =~ s/[\r\n]+//g;
			foreach my $chan (@channels) {
				my $channel = (split(',', $chan))[0];
				my $commitmsgs = join("\002' & '\002", @output);
				$commitmsgs = "'\002" . $commitmsgs . "\002'";

				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303svn\003 commit by \00303$author\003 \002*\002 r\002$revision\002: $commitmsgs");
				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303svn\003 files: $filemsg");
#				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-------\003 \002SVNCOMMiT\002 \00303-------\003");
#				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303--\003 Author: $author Revision: $revision");
#				foreach my $line (@output) {
#					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-\003 $line");
#				}
#
#				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-----\003 \002CHANGED FiLES\002 \00303-----\003");
#				$kernel->post('pzs-ng', 'privmsg', $channel, "\00303--\003 ". scalar @files ." file(s)");
#				my $i = 0;
#				foreach my $file (@files) {
#					$i++;
#					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-\003 $file");
#					if ($i > 5 && @files >= $i + 2) { last; }
#				}
#				if ($i < @files) {
#					$kernel->post('pzs-ng', 'privmsg', $channel, "\00303-\003 (". @files - $i ." file(s) not shown)");
#				}
			}
		}
		$youngest = $ryoungest;1
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
POE::Session->new( 'main' => [qw(_start _stop irc_001 irc_disconnected irc_error irc_socketerr irc_public irc_ctcp_version tick child_stdout sigchld)]);
$poe_kernel->run();

untie %factoids;

exit 0;
