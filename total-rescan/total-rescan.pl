#!/usr/bin/perl
############## ############## ############## ############## ############## ######## #### ## #
# total-rescan (c) daxxar ^ team pzs-ng <daxxar@mental.mine.nu> 
#  - version 1.3 rc1
#

#.########################################################################,
 # THIS SCRIPT *MUST* RUN AS ROOT, DUE TO chroot! IT CANNOT RUN WITHOUT!  #
 # (will give an error like "- Chroot failed! (Operation not permitted)") #
#`#######################################################################´

#
# info:
#  this is a pure perlscript, and also not using any modules.
#  it rescans a dir and all subdirs that contain a .sfv. this is
#  probably only useful if you've had fsck delete some files or if 
#  you've moved files to the site without using ftp, or before
#  zipscript was installed. it runs a given rescan binary from chroot
#  inside any dirs that have a .sfv-file. :-)
#  it will print one line for each 'rescan', and it'll be "+ PASSED:" or
#  "- FAILED:", based on the returnvalue of rescan binary. all output
#  from the rescan binary is supressed. :)
#
# config/setup:
#  requires NO config or setup, unless glroot/bin/rescan isn't your rescan binary.
#  if so, change '$rescan'-variable below. the only other things you need to take
#  care of is commandline. you run the script with:
#   ./total-rescan.pl PATH-I-WANT-TO-RESCAN GLFTPD-ROOT-DIRECTORY
#  GLFTPD-ROOT-DIRECTORY is optional, defaults to /glftpd (should be ok for most people).
#  PATH-I-WANT-TO-RESCAN is RELATIVE to GLFTPD-ROOT-DIRECTORY, so if you do this:
#  ./total-rescan.pl site/games
#  it will rescan /glftpd/site/games/, and not ./site/games/.
#  morale is: remember to include site/-prefix, if you need it. :-) (thanks _-] :)
#  
# history:
#  version 1 is a full rewrite of total-rescan 0.x,
#  so i thought giving it its own version number was
#  the least i could do ;) 
#  
# changelog:
#  from 1.2
#  * rmlog.sh was accidentally overwritten at end of script, fixed. 
#
#  from 1.1
#  + rmlog.sh-generate feature. :-) (script to remove all failed dirs)
#  * rmlog.sh generated in / now. :)
#  * rmlog.sh now generates newlines, and fixed a broken conditional :)
#  * total-rescan actually (perhaps) works. (note to self: rescan always
#    returns null, no matter what)
#  ! rmlog.sh is cleaned out at start of run, and prints two lines. ;)
#
#  from 1.0
#   ! output messages
#   * not working due to no chdir to / after chroot
#   * not working due to a misnamed sub (recandirs, not rescandirs)
#   - check for absolute path
#
#  from 0.x
#   ! full rewrite
#
# key   description
#  +    added
#  -    removed
#  *    bugfix
#  !    change
# (please, report bugs and / or send feature requests to daxxar@mental.mine.nu)
############## ############## ############## ############## ############## ######## #### ## #

use warnings;
use strict;

my $rescan = 'bin/rescan'; # Change if you've moved it / using another rescanner.
my $version = '.3 rc1';
my $rmscript = 'rmlog.sh';	# Generates 'rmlog.sh' in currentdir, containing rm -rf "$dir" on all failed rels.
							# Set to '' to disable this feature. ;-)

print "+ Starting total rescan v1$version by daxxar ^ team pzs-ng.\n";

my $path = shift;
my $glroot = shift || '/glftpd';
$glroot =~ s/(?<!\/)$/\//;
$path =~ s/\/$//;

if (!defined($path)) {
	print STDERR "- Path to scan not defined, exiting.\n";
	print STDERR "  (syntax: $0 <path> [glroot], path is relative to glroot)\n";
	exit 1;
}

if (! -d "${glroot}/${path}") {
	print STDERR "- Could not start total-rescan on '${glroot}${path}', dir does not exist!\n";
	print STDERR "  (syntax: $0 <path> [glroot], path is relative to glroot)\n";
	exit 1;
}

sub getdirs {
	my @dlist = (shift);
	my @dirs = @dlist;
	while ((my $dir = shift @dirs)) {
		if (!opendir(DIR, $dir)) {
			print STDERR "- Opening directtory '$dir' for reading failed, skipping! ($!)\n";
			next;
		}
		while (($_ = readdir(DIR))) {
			if (/^\./ || ! -d "$dir/$_") { next; }
			unshift(@dirs, "$dir/$_"); 
			push(@dlist, "$dir/$_");
		}
		closedir(DIR);
	}
	return @dlist;
}

sub getsfvdirs {
	my @dlist = @_;
	my @sfvdlist;
	DIR: foreach my $dir (@dlist) {
		if (!opendir(DIR, $dir)) {
			print STDERR "- Opening directory '$dir' for reading failed, skipping! ($!)\n";
			next;
		}
		
		while (($_ = readdir(DIR))) {
			if (/^\./ || -d "$_") { next; }
			if (/\.sfv$/i) {
				push(@sfvdlist, $dir);
				closedir(DIR);
				next DIR;
			}
		}
	}
	return @sfvdlist;
}

sub rescandirs {
	my @dirs = @_;
	foreach my $dir (@dirs) {
		if (!chdir($dir)) {
			print STDERR "- Changing dir to '$dir' failed, skipping! ($!)\n";
			next;
		}

		my $output = `/bin/rescan`;
		my ($passed, $total) = (-1, -1);
		if ($output =~ /Passed ?: ?(\d+)$/m) { $passed = $1; }
		if ($output =~ /Total ?: ?(\d+)$/m) { $total = $1; }
		
		if ($passed == -1 || $total == -1) {
			print "- ERROR! Output from /bin/rescan on '$dir' was unparseable. (Nonstandard rescan binary?)\n";
		} elsif ($passed == $total) {
			print "+ PASSED: $dir\n";
		} else {
			print STDERR "- FAILED: $dir\n";
			if (defined($rmscript) && $rmscript ne '') {
				open(RMLOG, '>>', "/$rmscript");
				print RMLOG "rm -rf '$glroot$dir'\n";
				close(RMLOG);
			}
		}
		
		chdir('/');
	}
}

print "+ Changing root for script to '$glroot' and changing dir to '/'.\n";
if (!chroot($glroot)) {
	print STDERR "- Changing root failed! ($!)\n";
	exit 1;
}
if (!chdir('/')) {
	print STDERR "- WTF? Changing dir to '/' failed! ($!)\n";
	exit 1;
}

print "+ Cleaning rmscript (/$rmscript)\n";
open(RMLOG, '>', "/$rmscript");
print RMLOG "echo '* Starting deletion of failed dirs.. :)'\n";
close(RMLOG);

print "+ Caching directories recursively.\n";
my @dirs = getdirs($path);

print "+ Scanning dirs for sfv-files.\n";
my @sfvdirs = getsfvdirs(@dirs);
if (!@sfvdirs) {
	print STDERR "! Could not find any dirs containing any SFVs under '$path', exiting.\n";
	exit 1;
}

print "+ Rescanning all dirs.\n";
rescandirs(@sfvdirs);

print "+ Adding 'closing entry' to rmscript ;)\n";
open(RMLOG, '>>', "/$rmscript");
print RMLOG "echo '* All done with deletion! :D'\n";
close(RMLOG);

print "+ Done! :)\n";
