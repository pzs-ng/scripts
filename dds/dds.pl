#!/usr/bin/perl -w
# DSS - daxxar's DayStats (c) daxxar <daxxar@daxxar.com>
# Perlscript for fetching various (un)useful information from logs.
# All settings are in dds.conf, read comments in the file carefully.
# Read "README" *NOW*!

use strict;
use Data::Dumper;
use FindBin qw($Bin);

# String to match for correct day =) (uses "localtime" and a regex to make a regex)
my $match = localtime;
if ($match =~ /\S+ (\S+)\s+(\d+) \d+:\d+:\d+ (\d+)/) {
    $match = "\\S+ $1 " . (length($2) == 1 ? '[0\s]?' : '') . "$2 \\d+:\\d+:\\d+ $3 ";
} else { equit("Couldn't match $match to a proper regex. *sigh*"); }

# Check if date / debug param is specified
my $debug = 0;
for my $arg (@ARGV) {
    if (lc($arg) eq 'debug') { $debug = 1 if (lc($arg) eq 'debug'); }
    elsif ($arg =~ /^(?:Jan|Feb|Mar|Apr|Jun|Jul|Aug|Sep|Oct|Nov|Dec)$/i) { $match =~ s/(?<=\\S\+ )\S+/$arg/; }
    elsif ($arg =~ /^\d\d?$/) {
        $match =~ s/(?<=\\S\+ )(\S+) \d+/$1 $arg/ if ($arg > 10);
        $match =~ s/(?<=\\S\+ )(\S+) \d+/$1 0$arg/ if ($arg < 10);
    }
    elsif ($arg =~ /^\d\d\d\d$/) { $match =~ s/\d{4} $/$arg /; }
}

# This is for what to read from config ^_^
my %vars = ( 'postfix' => '', 'prefix' => '', 'glroot' => '/glftpd', 'subnuked' => 'no' );
my %arrays = ( 'output' => [], 'noxferpaths' => [], 'exclude' => [] );
my %hashes = ( 'logs' => {} , 'tags' => {} , 'regex' => {} );

# This is the "tags" for different entries in
# the logs, for those we just count
$hashes{'tags'}{'reqfilled'} = 'REQFILLED:';
$hashes{'tags'}{'request'}   = 'REQUEST:';
$hashes{'tags'}{'new'}       = 'NEWDIR:';
$hashes{'tags'}{'del'}       = 'DELDIR:';

# $1 = username
$hashes{'regex'}{'login-who'}   = 'LOGIN: .+?@.+? \(.+?\) \S+ "([^\"]+)"';
# $1 = username
$hashes{'regex'}{'logout-who'}  = 'LOGOUT: .+?@.+? \(.+?\) "([^\"]+)"';
# $1 = username
$hashes{'regex'}{'timeout-who'} = 'TIMEOUT: (\S+)';
# $1 = nukees
$hashes{'regex'}{'nuke'}        = '^NUKE: "[^\"]+" "[^\"]+" "\d+" "[^\"]+" (.*)';
# $1 = unnukees
$hashes{'regex'}{'unnuke'}      = '^UNNUKE: "[^\"]+" "[^\"]+" "\d+" "[^\"]+" (.*)';
# $1 = nukee/unnukee, $2 = nuke-amount
$hashes{'regex'}{'nuke-each'}   = '"([^"]+) (\d+\.\d+)"';

# $1 = bytes, $2 = filepath, $3 = incoming/outgoing, $4 = user, $5 = group
$hashes{'regex'}{'xfer-stats'}  = '\d+ .+? (\d+) (\S+) [ba] _ ([io]) r (\S+) (\S+)';

# This is the files we are reading / writing from / to.
# output = glftpd-log to print to
# login = login-log to read from
# main = glftpd-log to read from
# xfer = xfer-log to read from
$hashes{'logs'}{'output'} = '%glroot/ftp-data/logs/glftpd.log';
$hashes{'logs'}{'login'}  = '%glroot/ftp-data/logs/login.log';
$hashes{'logs'}{'main'}   = '%glroot/ftp-data/logs/glftpd.log';
$hashes{'logs'}{'xfer'}   = '%glroot/ftp-data/logs/xferlog';
$hashes{'logs'}{'foopre'} = '%glroot/ftp-data/logs/foo-pre.log';

open(CONFIG, "$Bin/dds.conf")
  or equit("Couldnt open $Bin/dds.conf for reading!");
while (<CONFIG>) {
    s/[\r\n]+$//g;
    my $line = $_;
    if ($line =~ /^#/) { next; }
    if ($line =~ /([^\.\n]+?)\.(\S+?)\s*=.*?\'(.+)\'/) {
        my $type = $1; my $id = lc($2); my $value = $3;
        if ($type eq 'var') {
            if (defined($vars{$id})) {
                $vars{$id} = $value;
            } else {
                print STDERR "Configfile has an invalid var name ($id) on line $. of config.\n"
            }
        } elsif ($type eq 'array') {
            if (defined($arrays{$id})) {
                push(@{$arrays{$id}}, $value);
            } else {
                print STDERR "Configfile has an invalid array name ($id) on line $. of config.\n"
            }
        } elsif ($type eq 'hash') {
            my ($name,$key) = split(/\./, $id);
            if (defined($hashes{$name})) {
                $hashes{$name}{$key} = $value;
            } else {
                print STDERR "Configfile has an invalid hash-name ($name) on line $. of config.\n"
            }
        } else {
            print STDERR "Configfile has an invalid type ($type) on line $. of config.\n";
        }
    }
}
close(CONFIG);

for my $val (values %{$hashes{'logs'}}) { $val =~ s/\%glroot/$vars{'glroot'}/g; }

if ($debug) {
    print "Vars read from config to \%vars:\n";
    print Dumper \%vars;
    print "Arrays read from config to \%arrays:\n";
    print Dumper \%arrays;
    print "Hashes read from config to \%hashes:\n";
    print Dumper \%hashes;
}

for my $k (keys %{$hashes{'regex'}})
{
    $hashes{'regex'}{$k} = qr/$hashes{'regex'}{$k}/;
}

# Convert *from* bytes to a higher unit.
sub from_byte {
    my $size = shift; my $x = 0;
    my @y = ('b', 'kB', 'MB', 'GB', 'TB');
    while ($size >= 1024 && $x < @y) { $size = $size / 1024; $x++; } 
    return sprintf("%.1f", $size) . $y[$x];
}
# Error quit; quit with return num 1 and print an error =)
sub equit {
    my $msg = shift;
    print "Fatal: $msg\n";
    exit 1;
}

open(OUTPUT, '>>', $hashes{'logs'}{'output'})
  or equit "Can't open $hashes{logs}{output} for appending!";
close(OUTPUT);

my (%stats, %logins, %logouts, %timeouts);
open(LOGINS, '<', $hashes{'logs'}{'login'})
  or equit "Can't open login-file ($hashes{logs}{login}) for reading!";

while (<LOGINS>) {
    s/[\r\n]+$//g;
    if (!/^$match/i) { next; }
    s/^$match//;
    if (/$hashes{'regex'}{'login-who'}/i) { $logins{$1}++ if defined($1); $stats{'logins'}++;
    } elsif (/$hashes{'regex'}{'logout-who'}/i) { $logouts{$1}++ if defined($1); $stats{'logouts'}++;
    } elsif (/$hashes{'regex'}{'timeout-who'}/i) { $timeouts{$1}++ if defined($1); $stats{'timeouts'}++; }
}
close(LOGINS);

# size of files leeched by user, size of files upped by user,
# # of files leeched by user, # of files upped by user, user -> group lookup
my (%leechersize, %uppersize, %leecherfiles, %upperfiles, %grouplookup);
open(XFER, '<', $hashes{'logs'}{'xfer'}) 
  or equit "Can't open xfer-file ($hashes{'logs'}{'xfer'}) for reading!";

LINE: while (<XFER>) {
    s/[\r\n]+$//g;
    if (!/^$match/i) { next; }
    s/^$match//;
    if (/$hashes{'regex'}{'xfer-stats'}/i) {
        my $bytes = $1; my $path = $2; my $io = $3;
        my $user = $4; my $group = $5;
        for my $skip (@{$arrays{'noxferpaths'}}) { next LINE if ($path =~ /^$skip/); }
        for my $skipgroup (@{$arrays{'exclude'}}) { next LINE if ($group eq $skipgroup); }

        $grouplookup{$user} = $group;
        if ($io eq 'i') {
            $uppersize{$user} += $bytes;
            $stats{'usize'} += $bytes;
            $upperfiles{$user}++;
            $stats{'ufiles'}++;
        } elsif ($io eq 'o') {
            $leechersize{$user} += $bytes;
            $stats{'lsize'} += $bytes; 
            $leecherfiles{$user}++;
            $stats{'lfiles'}++;
        }
    }
}
close(XFER);

my (%pres, %nukees);
open(MAIN, '<', $hashes{'logs'}{'main'})
  or equit "Can't open main-log ($hashes{logs}{main}) for reading!";

while (<MAIN>) {
    s/[\r\n]+$//g;
    if (!/^$match/i) { next; }
    s/^$match//;
    if (/$hashes{'regex'}{'pre-who'}/i) { $pres{$1}++; $stats{'pres'}++; next;}
    if (/$hashes{'regex'}{'nuke'}/i)
    {
        $stats{'nukes'}++;
        my $nukees = $1;
        while ($nukees =~ /$hashes{'regex'}{'nuke-each'}/gc)
        {
            my ($user, $kb) = ($1, $2);
            if (lc($vars{'subnuked'}) eq 'yes')
            {
                $uppersize{$user} -= $kb * 1024;
            }

            if (!defined($nukees{$user})) { $nukees{$user} = []; }

            $nukees{$user}->[0] += ($kb * 1024);
            $nukees{$user}->[1]++;
        }
        next;
    }
    if (/$hashes{'regex'}{'unnuke'}/i) {
        $stats{'unnukes'}++;
        my $nukees = $1;
        while ($nukees =~ /$hashes{'regex'}{'nuke-each'}/gc)
        {
            my ($user, $kb) = ($1, $2);
            if (lc($vars{'subnuked'}) eq 'yes')
            {
                $uppersize{$user} += $kb * 1024;
            }

            if (!defined($nukees{$user})) { $nukees{$user} = []; }

            $nukees{$user}->[0] -= ($kb * 1024);
            $nukees{$user}->[1]--;
            if ($nukees{$user}->[1] == 0) { delete $nukees{$user} }
        }
        next;
    }
    foreach my $key (keys %{$hashes{'tags'}}) {
        if (/^$hashes{'tags'}{$key}/i) { $stats{$key}++; last; }
    }
}

close(MAIN);

my @topup = reverse sort { $uppersize{$a} <=> $uppersize{$b} } keys %uppersize;
my @topdn = reverse sort { $leechersize{$a} <=> $leechersize{$b} } keys %leechersize;
my @topli = reverse sort { $logins{$a} <=> $logins{$b} } keys %logins;
my @toplo = reverse sort { $logouts{$a} <=> $logouts{$b} } keys %logouts;
my @topto = reverse sort { $timeouts{$a} <=> $timeouts{$b} } keys %timeouts;
my @toppre = reverse sort { $pres{$a} <=> $pres{$b} } keys %pres;
my @topnuke = reverse sort { $nukees{$a}->[0] <=> $nukees{$b}->[0] } keys %nukees;

foreach my $upper (keys %uppersize) {$uppersize{$upper} = from_byte($uppersize{$upper});}
foreach my $leecher (keys %leechersize) {$leechersize{$leecher} = from_byte($leechersize{$leecher});}

open(OUTPUT, '>>', $hashes{'logs'}{'output'})
  or equit "Can't open $hashes{logs}{output} for appending!" if (!$debug);

my ($sec, $min, $hour, $day, $month, $year, $wday, $yday, $isdst) = localtime;

foreach my $line (@{$arrays{'output'}}) {
    $line =~ s/(?<!%)%topup\[(\d+)\]/defined $topup[$1-1] ? $topup[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%topupf\[(\d+)\]/(defined $topup[$1-1] && defined $upperfiles{$topup[$1-1]}) ? $upperfiles{$topup[$1-1]} : '0'/eg;
    $line =~ s/(?<!%)%topups\[(\d+)\]/(defined $topup[$1-1] && defined $uppersize{$topup[$1-1]}) ? $uppersize{$topup[$1-1]} : '0b'/eg;

    $line =~ s/(?<!%)%topdn\[(\d+)\]/defined $topdn[$1-1] ? $topdn[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%topdnf\[(\d+)\]/(defined $topdn[$1-1] && defined $leecherfiles{$topdn[$1-1]}) ? $leecherfiles{$topdn[$1-1]} : '0'/eg;
    $line =~ s/(?<!%)%topdns\[(\d+)\]/(defined $topdn[$1-1] && defined $leechersize{$topdn[$1-1]}) ? $leechersize{$topdn[$1-1]} : '0b'/eg;

    $line =~ s/(?<!%)%totups/defined $stats{'usize'} ? from_byte($stats{'usize'}) : '0b'/eg;
    $line =~ s/(?<!%)%totdns/defined $stats{'lsize'} ? from_byte($stats{'lsize'}) : '0b'/eg;
    $line =~ s/(?<!%)%totupf/defined $stats{'ufiles'} ? $stats{'ufiles'} : '0'/eg;
    $line =~ s/(?<!%)%totdnf/defined $stats{'lfiles'} ? $stats{'lfiles'} : '0'/eg;

    $line =~ s/(?<!%)%trafs/(defined $stats{'usize'} && defined $stats{'lsize'}) ? from_byte($stats{'usize'}+$stats{'lsize'}) : (defined $stats{'usize'} ? from_byte($stats{'usize'}) : (defined $stats{'lsize'} ? from_byte($stats{'lsize'}) : '0b'))/eg;
    $line =~ s/(?<!%)%traff/(defined $stats{'ufiles'} && defined $stats{'lfiles'}) ? $stats{'ufiles'}+$stats{'lfiles'} : (defined $stats{'ufiles'} ? $stats{'ufiles'} : (defined $stats{'lfiles'} ? $stats{'lfiles'} : '0'))/eg;

    $line =~ s/(?<!%)%topli\[(\d+)\]/defined $topli[$1-1] ? $topli[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%toplo\[(\d+)\]/defined $toplo[$1-1] ? $toplo[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%toplic\[(\d+)\]/(defined $topli[$1-1] && defined $logins{$topli[$1-1]}) ? $logins{$topli[$1-1]} : '0'/eg;
    $line =~ s/(?<!%)%toploc\[(\d+)\]/(defined $toplo[$1-1] && defined $logouts{$toplo[$1-1]}) ? $logouts{$toplo[$1-1]} : '0'/eg;
    $line =~ s/(?<!%)%topto\[(\d+)\]/defined $topto[$1-1] ? $topto[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%toptoc\[(\d+)\]/(defined $topto[$1-1] && defined $timeouts{$topto[$1-1]}) ? $timeouts{$topto[$1-1]} : '0'/eg;

    $line =~ s/(?<!%)%totli/defined $stats{'logins'} ? $stats{'logins'} : '0'/eg;
    $line =~ s/(?<!%)%totlo/defined $stats{'logouts'} ? $stats{'logouts'} : '0'/eg;
    $line =~ s/(?<!%)%totto/defined $stats{'timeouts'} ? $stats{'timeouts'} : '0'/eg;

    $line =~ s/(?<!%)%toppre\[(\d+)\]/defined $toppre[$1-1] ? $toppre[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%topprec\[(\d+)\]/(defined $toppre[$1-1] && defined $pres{$toppre[$1-1]}) ? $pres{$toppre[$1-1]} : '0'/eg;
    $line =~ s/(?<!%)%prec/defined $stats{'pres'} ? $stats{'pres'} : '0'/eg;

    $line =~ s/(?<!%)%topnuke\[(\d+)\]/defined $topnuke[$1-1] ? $topnuke[$1-1] : 'None'/eg;
    $line =~ s/(?<!%)%topnukes\[(\d+)\]/(defined $topnuke[$1-1] && defined $nukees{$topnuke[$1-1]}) ? from_byte($nukees{$topnuke[$1-1]}->[0]) : '0b'/eg;
    $line =~ s/(?<!%)%topnukec\[(\d+)\]/(defined $topnuke[$1-1] && defined $nukees{$topnuke[$1-1]}) ? $nukees{$topnuke[$1-1]}->[1] : '0'/eg;
    $line =~ s/(?<!%)%nukec/defined $stats{'nukes'} ? $stats{'nukes'} : '0'/eg;
    $line =~ s/(?<!%)%unnukec/defined $stats{'unnukes'} ? $stats{'unnukes'} : '0'/eg;

    $line =~ s/(?<!%)%newdir/defined $stats{'new'} ? $stats{'new'} : '0'/eg;
    $line =~ s/(?<!%)%deldir/defined $stats{'del'} ? $stats{'del'} : '0'/eg;
    $line =~ s/(?<!%)%reqs/defined $stats{'request'} ? $stats{'request'} : '0'/eg;
    $line =~ s/(?<!%)%reqfills/defined $stats{'reqfilled'} ? $stats{'reqfilled'} : '0'/eg;

    $line =~ s/(?<!%)%yyyy/$year+1900/eg;
    $line =~ s/(?<!%)%yy/sprintf('%02d', $year%100)/eg;
    $line =~ s/(?<!%)%mm/sprintf('%02d', $month+1)/eg;
    $line =~ s/(?<!%)%dd/sprintf('%02d', $day)/eg;

    $line =~ s/(?<!%)%hh/sprintf('%02d', $hour)/eg;
    $line =~ s/(?<!%)%nn/sprintf('%02d', $min)/eg;
    $line =~ s/(?<!%)%ss/sprintf('%02d', $sec)/eg;

    $line =~ s/%%/%/g;
    $line =~ s/%c/\003/g if (!$debug);
    $line =~ s/%b/\002/g if (!$debug);

    my $pf = $vars{'prefix'};
    $pf =~ s/%tstamp/localtime/eg;

    print $pf . $line . $vars{'postfix'}. "\n" if ($debug);
    print OUTPUT $pf . $line . $vars{'postfix'}. "\n" if (!$debug);
}
close(OUTPUT) if (!$debug);
