#!/usr/bin/perl
############## ############## ############## ############## ############## ######## #### ## #
# total-rescan (c) daxxar ^ pzs-ng <daxxar@mental.mine.nu> 
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
#  ./total-rescan.pl games
#  it will rescan /glftpd/games/, and not games/.
#  
# history:
#  version 1 is a full rewrite of total-rescan 0.x,
#  so i thought giving it its own version number was
#  the least i could do ;) 
#  
# changelog:
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

if (!defined($path)) {
	print STDERR "- Path to scan not defined, exiting.\n";
	print STDERR "  (syntax: $0 <path> [glroot], path is relative to glroot)\n";
	exit 1;
}

if ($path =~ /^\//) {
	print STDERR "- Could not start total-rescan on '$path', no absolute paths!\n";
	print STDERR "  (paths are always relative to glroot, (in this case: '$glroot')\n";
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
			print STDERR "- Opendir on $dir failed, skipping! ($!)\n";
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
			print STDERR "- Opendir on $dir failed, skipping! ($!)\n";
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

sub recandirs {
	my @dirs = @_;
	foreach my $dir (@dirs) {
		if (!chdir($dir)) {
			print STDERR "- Chdir on $dir failed, skipping! ($!)\n";
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

print "+ Chrooting script to $glroot.\n";
if (!chroot($glroot)) {
	print STDERR "- Chroot failed! ($!)\n";
	exit 1;
}

print "+ Fetching directories recursively.\n";
my @dirs = getdirs($path);

print "+ Finding what dirs contain one (or more) sfv-file(s).\n";
my @sfvdirs = getsfvdirs(@dirs);
if (!@sfvdirs) {
	print STDERR "! Could not find any dirs containing SFVs under '$path', exiting.\n";
	exit 1;
}

print "+ Rescanning all dirs.\n";
rescandirs(@sfvdirs);

print "+ Done! :)\n";
