#!/usr/bin/perl
############## ############## ############## ############## ############## ######## #### ## #
# total-rescan (c) daxxar ^ team pzs-ng <daxxar@mental.mine.nu> 
#  - version 1.0
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
my $version = '.0';

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

		if (system('/bin/rescan')) {
			print STDERR "- FAILED: $dir (retcode: ". ($? >> 8) .")\n";
		} else {
			print "+ PASSED: $dir\n";
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

print "+ Done! :)\n";
