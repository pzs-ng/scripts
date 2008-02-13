#!/usr/bin/perl

use warnings;
use strict;

use FindBin qw($Bin);
use Net::FTP;
use Digest::MD5;

use Data::Dumper;

$| = 1;

my ($verbose, $quiet) = (0, 0);
if (@ARGV && $ARGV[0] eq 'verbose') { shift; $verbose = 1; }
if (!$verbose && (@ARGV && $ARGV[0] eq 'quiet')) { shift; $quiet = 1; }

# This is for what to read from config ^_^
my %vars = (
	sync_deleted => 'yes',
	templatedir => 'templates',
	outputdir => 'pages',
	quotes_file => 'quotes',
	mirrorlinks_sep => ' - ',
	domain => 'pzs-ng.com',
	stable_local => 'stable',
	stable_remote => 'stable',
	testing_local => 'testing',
	testing_remote => 'testing',
	unstable_local => 'unstable',
	unstable_remote => 'unstable',
	volatile_local => 'volatile',
	volatile_remote => 'volatile',
	default_password => 'anonymous@',
	default_passive => 'yes'
);

#my %arrays = ( 'pages' => [] );
my %arrays;
my %hashes = ( 'mirrors' => {} );

my (%local_files, %templates);

sub vprint {
	print @_ if ($verbose);
}
sub evprint {
	print @_ if ($verbose || $quiet);
}
sub eprint {
	#print STDERR @_;
	print @_;
	return 0;
}
sub nprint {
	print @_ if (!$quiet);
}
sub nvprint {
	print @_ if (!$quiet && !$verbose);
}

my @quotes;

sub parse_template_line {
	my $country = shift or die "Called parse_template_line with invalid parameters (missing all params)\n";
	my $page = shift or die "Called parse_template_line with invalid parameters (missing second param (page))\n";
	my $line = shift or die "Called parse_template_line with invalid parameters (missing third param (line))\n";

	my $url = "http://$country.$vars{domain}";

	my $mirror_links;
	foreach my $cc (sort {$a cmp $b} keys %{$hashes{'mirrors'}}) {
		if ($cc ne $country) {
			$mirror_links .= "<a href='http://$cc.$vars{domain}/'>$cc</a>". $vars{'mirrorlinks_sep'};
		} else {
			$mirror_links .= $cc . $vars{'mirrorlinks_sep'};
		}
	}
	$mirror_links =~ s/$vars{'mirrorlinks_sep'}$//;

	my %file_links = ( 'stable' => [], 'testing' => [], 'unstable' => [], 'volatile' => [] );
	for my $type ('stable', 'testing', 'unstable', 'volatile') {
		my @keys = reverse sort { $local_files{$type}{$a}[1] cmp $local_files{$type}{$b}[1] } keys %{$local_files{$type}};
		if (!@keys) { push(@{$file_links{$type}}, "no files here at the moment."); }
		foreach my $file (@keys) {
			push(@{$file_links{$type}}, "<a href='$url/". $vars{$type .'_remote'}
										."/$file'>$file</a>, $local_files{$type}{$file}[0] bytes. md5sum: $local_files{$type}{$file}[2].");
#					. "last modified: ". localtime($local_files{'stable'}{$file}[1]) ."<br>\n";
		}
	}

	while ($line =~ /\%file_links{([^,}]+),([^}]*)}/) {
		my ($type, $prefix) = ($1, $2);
		my $string;
		if (exists($file_links{$type})) {
			my @tmp = @{$file_links{$1}};
			foreach my $file (@tmp) {
				$string .= "${prefix}${file}<br>\n";
			}
		} else {
			$string = "${prefix}Invalid section specified in cookie, contact pzs-ng crew.";
		}
		$line =~ s/\%file_links{$type,$prefix}/$string/g;
	}
	
	$line =~ s/\%newest_file{([^}]+)}/
		my $type = $1;
		if (exists($local_files{$type})) {
			my $file = (reverse sort { $local_files{$type}{$a}[1] cmp $local_files{$type}{$b}[1] } keys %{$local_files{$type}})[0];
			"<a href='". $vars{$type .'_remote'}."\/$file'>$file<\/a>";
		} else {
			"Invalid section specified in cookie, contact pzs-ng crew.";
		}/eg;
	$line =~ s/\%time_of_generation/scalar localtime/eg;
	$line =~ s/\%mirror_links/$mirror_links/g;
	$line =~ s/\%country/$country/g;

	my $randquote = $quotes[int(rand(@quotes))];
	$randquote =~ s/</&lt;/g; $randquote =~ s/>/&gt;/g;
	$randquote =~ s/\\n/<br>\n &nbsp; /g;
	$line =~ s/\%random_quote/ &nbsp; $randquote/g;

	if ($line =~ /\%quotes/) {
		my $quoteString = '';
		my $qnum = @quotes;
		for (reverse @quotes) {
			my $quote = $_;
			$quoteString .= 'Quote #<b>' . $qnum-- . "</b><br>\n";
			$quoteString .= "-------------<br>\n";
			$quote = ' &nbsp; ' . $quote;
			$quote =~ s/</&lt;/g; $quote =~ s/>/&gt;/g;
			$quote =~ s/\\n/<br>\n &nbsp; /g;
			$quoteString .= $quote . "<br><br>\n";;
		}
		$line =~ s/\%quotes/$quoteString/g;
	}
	
	return $line;
}

sub generate_page {
	my $country = shift or die "Called generate_page with invalid parameters (missing all params)\n";
	my $page = shift or die "Called generate_page with invalid parameters (missing second param (page))\n";
	my @lines = @_;

	open(PAGE, '>', "$vars{outputdir}/$page")
	  or warn("Could not open '$vars{outputdir}/$page' for page generation. (OUTPUT FILE) (country: $country)") and return 0;

	foreach my $line (@lines) {
		if ($line eq '') { $line = ' ' }
		print PAGE parse_template_line($country, $page, $line) . "\n";
	}

	close(PAGE);

	1;
}

sub parse_link {
	my $link = shift; 
	my %parts;

	$parts{'user'} = 'anonymous';
	$parts{'pass'} = $vars{'default_password'}; 
	$parts{'port'} = 21;
	$parts{'dir'} = '/';
	$parts{'passive'} = ($vars{'default_passive'} =~ /y(es)?/i ? 1 : 0);
	
	if ($link =~ /^ftp:\/\//) { $link =~ s/^ftp:\/\///;
	} elsif ($link =~ /^active:\/\//) {
		$parts{'passive'} = 0;
		$link =~ s/^active:\/\///;
	} elsif ($link =~ /^(passive|pasv):\/\//) {
		$parts{'passive'} = 1;
		$link =~ s/^(passive|pasv):\/\///;
	}
	
	if ($link =~ /^([^:]+):([^@]+)@/) {
		$parts{'user'} = $1;
		$parts{'pass'} = $2;
	} elsif ($link =~ /^([^:]+)@/) { $parts{'user'} = $1; }

	if ($link =~ /@([^\/]+)/) {
		$parts{'host'} = $1;
	} else { die("Invalid hostname on URL $link.\n"); }
	
	if ($link =~ /@[^\/]+\/(.*?)$/) { $parts{'dir'} = $1; }

	return %parts;
}

sub recursive_rm {
	my ($ftp, $dir) = @_;
	
	my $pwd = $ftp->pwd();
	$ftp->cwd($dir);
	my @files = $ftp->ls();
	for my $file (@files) {
		next if $file =~ /^\.\.?$/;
		# A hack.
		if (!$ftp->delete($file))
		{
			recursive_rm($ftp, $file);
		}
	}
	$ftp->cwd($pwd);
	$ftp->rmdir($dir);
}

sub sync_files {
	my ($country, $mode) = @_;
	my %site = parse_link($hashes{'mirrors'}{$country});
	
	my $ftp = Net::FTP->new($site{'host'}, Debug => 0, Port => $site{'port'}, Passive => $site{'passive'})
	  or return eprint "    ! Error connecting to $country.$vars{domain}: $@\n";
	vprint "    - Connected with" . ($site{'passive'} ? '' : 'out') ." passive mode. :)\n";
	$ftp->login($site{'user'}, $site{'pass'})
	  or return eprint "    ! Could not login to $country.$vars{domain}: ". $ftp->message . "\n";
	$ftp->cwd($site{'dir'})
	  or return eprint "    ! Could not cwd on $country.$vars{domain}: ". $ftp->message . "\n";
	$ftp->binary
	  or return eprint "    ! Could not change to binary mode on $country.$vars{domain}: ". $ftp->message . "\n";

	my %dirs_exist = ($vars{'unstable_remote'} => 0, $vars{'stable_remote'} => 0, $vars{'testing_remote'} => 0, $vars{'volatile_remote'} => 0);
	vprint "    - Deleting or checking for existing files.\n";
	my @files = $ftp->ls();
	for my $file (@files) {
		vprint "    - Found $file.\n";
		if (exists($dirs_exist{$file})) {
			if ($mode eq 'wipe') {
				vprint "     - Wiping!\n";
				recursive_rm($ftp, $file);
#				$ftp->rmdir($file, 1)
#				  or return eprint "    ! Could not do a recursive rmdir on $country.$vars{domain}: ". $ftp->message ."\n";
			} else {
				vprint "     - Marked as found!\n";
				$dirs_exist{$file} = 1;
			}
		} elsif (exists($templates{$file})) {
			vprint "     - Deleting!\n";
			$ftp->delete($file);
		}	
	}

	
	vprint "    - Creating neccessary directory structure.\n";
	for my $dir (keys %dirs_exist) {
		if (!$dirs_exist{$dir}) {
			$ftp->mkdir($dir)
			  or return eprint "    ! Could not mkdir $dir on $country.$vars{domain}: ". $ftp->message . "\n";
		}
	}

	my %dirs_remote = (unstable => $vars{'unstable_remote'}, stable => $vars{'stable_remote'}, testing => $vars{'testing_remote'}, volatile => $vars{'volatile_remote'});
	my %dirs_local = (unstable => $vars{'unstable_local'}, stable => $vars{'stable_local'}, testing => $vars{'testing_local'}, volatile => $vars{'volatile_local'});
	for my $key (keys %dirs_remote) {
		my @files = $ftp->ls($key);
		s/^$key\/?// for @files;
		@files = grep {!/^\./} @files;

		my %count = ();
		foreach my $element (@files, keys %{$local_files{$key}}) { $count{$element}++ }
		for my $file (keys %{$local_files{$key}}) {
			if ($count{$file} == 1) {
				vprint "    - Uploading '$dirs_local{$key}/$file' as '$dirs_remote{$key}/$file'\n";
				$ftp->put("$dirs_local{$key}/$file", "$dirs_remote{$key}/$file")
				  or return eprint "    ! Could not upload file on $country.$vars{domain}: ". $ftp->message . "\n";
			}
		}
		if ($vars{'sync_deleted'} =~ /y(es)?/i) {
			for my $file (@files) {
				if ($count{$file} == 1) {
					vprint "    - Deleting file '$dirs_remote{$key}/$file' which is not in local fs (sync_deleted).\n";
					$ftp->delete("$dirs_remote{$key}/$file")
					  or return eprint "    ! Could not delete files on $country.$vars{domain}: ". $ftp->message . "\n";
				}
			}
		}
	}

	for my $page (keys %templates) {
		vprint "    - Uploading file '$vars{outputdir}/$page' as '$page'.\n";
		$ftp->put("$vars{outputdir}/$page", "$page")
		  or return eprint "    ! Could not upload file on $country.$vars{domain}: ". $ftp->message . "\n";
	}

	$ftp->quit;

	1;
}


nprint " * Preparing for sync.\n";

vprint "  - Reading tm.conf.\n";

open(CONFIG, "$Bin/tm.conf")
  or equit("Couldnt open $Bin/tm.conf for reading!");
while (<CONFIG>) {
	s/[\r\n]+$//g;
	my $line = $_;
	if ($line =~ /^#/) { next; }
	if ($line =~ /([^\.\n]+?)\.(\S+?)\s*=.*?\'(.+)\'/) {
		my $type = $1; my $id = lc($2); my $value = $3;
		if ($type eq 'var') {
			if (defined($vars{$id})) { $vars{$id} = $value; }
			else {
				print STDERR "Configfile has an invalid var name ($id) on line $. of config.\n"
			}
		} elsif ($type eq 'array') {
			if (defined($arrays{$id})) { push(@{$arrays{$id}}, $value); }
			else {
				print STDERR "Configfile has an invalid array name ($id) on line $. of config.\n"
			}
		} elsif ($type eq 'hash') {
			my ($name,$key) = split(/\./, $id);
			if (defined($hashes{$name})) { $hashes{$name}{$key} = $value; }
			else {
				print STDERR "Configfile has an invalid hash-name ($name) on line $. of config.\n"
			}
		} else {
			print STDERR "Configfile has an invalid type ($type) on line $. of config.\n";
		}
	}
}
close(CONFIG);

vprint "  - Cleaning / fixing some config variables.\n";
if ($vars{'outputdir'} !~ /^\//) { $vars{'outputdir'} = "$Bin/$vars{outputdir}"; }
if ($vars{'templatedir'} !~ /^\//) { $vars{'templatedir'} = "$Bin/$vars{templatedir}"; }
if ($vars{'stable_local'} !~ /^\//) { $vars{'stable_local'} = "$Bin/$vars{stable_local}"; }
if ($vars{'testing_local'} !~ /^\//) { $vars{'testing_local'} = "$Bin/$vars{testing_local}"; }
if ($vars{'unstable_local'} !~ /^\//) { $vars{'unstable_local'} = "$Bin/$vars{unstable_local}"; }
if ($vars{'volatile_local'} !~ /^\//) { $vars{'volatile_local'} = "$Bin/$vars{volatile_local}"; }
$vars{'outputdir'} =~ s/\/+$//g; $vars{'templatedir'} =~ s/\/+$//g;

my %sync_mirrors;
my $mode = 'update';

if (@ARGV) {
	$mode = shift if ($ARGV[0] eq 'wipe' || $ARGV[0] eq 'update');
	$sync_mirrors{(shift @ARGV)} = 1 while (@ARGV);
}
if (!(keys %sync_mirrors)) {
	foreach my $mirror (keys %{$hashes{'mirrors'}}) { $sync_mirrors{$mirror} = 1; }
}

my $length = 0;
$length = (length($_) > $length ? length($_) : $length) for (keys %sync_mirrors); 

vprint "  - Mode set to '$mode'.\n";

vprint "  - Caching template files.\n";
opendir(TEMPLATEDIR, $vars{'templatedir'});
while ((my $entry = readdir(TEMPLATEDIR))) {
	my $fentry = "$vars{templatedir}/$entry";
	if (! -f $fentry) { next; }
	if ($entry =~ /^\./) { next; }
	if ($fentry !~ /\.tpl$/) { next; }
	
	open(TEMPLATE, '<', "$vars{templatedir}/$entry");
	$entry =~ s/\.tpl$//;
	while (my $line = <TEMPLATE>) { $line =~ s/[\r\n]+$//g; push(@{$templates{$entry}}, $line); }
	close(TEMPLATE);
}
closedir(TEMPLATEDIR);


# Get all stable files, testing files and unstable files.
# Also, fetch stat() information (filesize + mtime).

my %loop = (stable => $vars{'stable_local'},
			testing => $vars{'testing_local'},
			unstable => $vars{'unstable_local'},
			volatile => $vars{'volatile_local'});

vprint "  - Caching list of pzsng-files.\n";
for my $key (keys %loop) {
	my $dir = $loop{$key};
	opendir(DIR, $dir);
	while ((my $entry = readdir(DIR))) {
		if (! -f "$dir/$entry") { next; }
		open(HANDLE, "$dir/$entry");
		my $ctx = Digest::MD5->new;
		$ctx->addfile(*HANDLE);
		
		$local_files{$key}{$entry} = [(stat("$dir/$entry"))[7], (stat("$dir/$entry"))[9], $ctx->hexdigest];

		close(HANDLE);
	}
	closedir(DIR);
}
vprint " + Preparation done.\n";

open(QUOTES, $vars{'quotes_file'});
push(@quotes, $_) while <QUOTES>;
close(QUOTES);

# Main part; loop all the countries set for syncing, and
# generate page, then upload page (+ files)

# Make sure our temporary output-dir before sync already exists. :-)
if (! -d $vars{'outputdir'}) { mkdir($vars{'outputdir'}); }

my $mirrorCount = 0;
nprint " * Starting sync of mirrors ($mode).\n";
foreach my $country (sort {$a cmp $b} keys %sync_mirrors) {
	if (!exists($hashes{'mirrors'}{$country})) {
		vprint "  - Skipping $country.$vars{domain} (mirror not (properly) configured in config).\n";
		next;
	}
	
	$mirrorCount++; 

	my $padding = " " x ($length - length($country) + 1);

	vprint "  * Syncing $country.$vars{domain}.\n";
	vprint "   - Generating pages.\n";
	foreach my $page (keys %templates) {
		vprint "    - Generating $page.\n";
		generate_page($country, $page, @{$templates{$page}});
	}
	vprint "   - Uploading files.\n";
	if (sync_files($country, $mode)) {
		vprint "  + Done with $country.$vars{domain}.\n";
		nvprint "  + $country.$vars{domain}:$padding OK\n";
	} else {
		$sync_mirrors{$country} = 0;
		evprint "  ! Failed on $country.$vars{domain}.\n";
		nvprint "  ! $country.$vars{domain}:$padding FAiLED\n";
	}
}
nprint " ! No (valid) mirrors specified.\n" if not $mirrorCount;
nprint " + Syncing done (attempted $mirrorCount mirror(s)).\n" if $mirrorCount;

vprint " + Cleaning up slightly.\n";
foreach my $page (keys %templates) { unlink("$vars{'outputdir'}/$page"); }

vprint " * Overview:\n";
foreach my $country (keys %sync_mirrors) {
	my $padding = " " x ($length - length($country) + 1);
	if ($sync_mirrors{$country}) {
		vprint "  + $country.$vars{domain}:$padding OK\n";
	} else {
		vprint "  ! $country.$vars{domain}:$padding FAiLED\n";
	}
}
vprint " + Done.\n";

0;
