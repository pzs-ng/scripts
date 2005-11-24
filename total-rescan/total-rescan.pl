#!/usr/bin/perl -w
############## ############## ############## ############## ############## ######## #### ## #
# total-rescan (c) daxxar ^ team pzs-ng <daxxar@daxxar.com> 
#  - version 1.4
#

#.########################################################################,
 # THIS SCRIPT *MUST* RUN AS ROOT, DUE TO chroot! IT CANNOT RUN WITHOUT!  #
 # (will give an error like "- Chroot failed! (Operation not permitted)") #
#`#######################################################################´

#
# info:
#  this is a pure perlscript, and also not using any modules.
#  it rescans a dir and all subdirs that contain a .sfv (or .zip, see $zipscan)
#  this is probably only useful if you've had fsck delete some files or if 
#  you've moved files to the site without using the ftpd, or before
#  zipscript was installed. it runs a given rescan binary from chroot
#  inside any dirs that have a .sfv/zip-file. :-) (see $zipscan)
#  it will print one line for each 'rescan', and it'll be "+ PASSED:" or
#  "- FAILED:", based on the returnvalue of rescan binary. all output
#  from the rescan binary is supressed. :)
#
#  as of 1.4 it also supports resorting audiolinks. this feature does the same
#  as rescan, minus the rescanning part. this requires pzs-ng v1.0.1b or equivilant.
#  it goes over all dirs, finds those with a .mp3, and sorts them into the pzs-ng-defined
#  sort dirs. :) for sorting, see $onlysort. (rescan sorts per default)
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
#  from 1.3
#  ! now chmods the rmscript to 755.
#  + $printeach setting, can be used to disable PASSED: and FAILED: for each rescan. (E.g. for big archives)
#  ! caching of dirs and such, to fix a potential abuse of memory ;-) (thanks to iRacer for reporting)
#     ^--- rewritten.
#  * getscandirs() now skip symlinks
#  + support for *only* sorting audioreleases, not rescanning. (needs pzs-ng v1.0.1 or equivilant)
#  * if $rmscript was '', it would produce warnings / errors.
#  + support for zip-rescanning too ;) (see $zipscan, default on)
#  + preserves mtime/atime of the dir being rescanned (thanks iNDi).
#    (see $preservestamp) this will (supposedly) make site new work ok. ;)
#  ! now you can set $stampfromfile to use first .sfv/.zip in the dir for the mtime/atime,
#    instead of the dir itself. :) (only if preservestmap)
#  * getscandirs wasn't closing the dirhandle if there were no zips/sfvs in a dir.
#  ! "path" is now "pattern"; glob-matched pattern. :)
#  * variablenames overlapping and output and such.
#  * slight syntax error.
#  ! lists my real email in here now. =P
#  * $rescan wasn't being used, at all. :)
#
#  from 1.2
#  * rmlog.sh was accidentally overwritten at end of script, fixed. 
#  ! didn't work with perl 5.005, switched to -w and two-argument open()
#
#  from 1.1
#  + rmlog.sh-generate feature. :-) (script to remove all failed dirs)
#  * rmlog.sh generated in / now. :)
#  * rmlog.sh now generates newlines, and fixed a broken conditional :)
#  * total-rescan actually (perhaps) works. (note to self: rescan always returns 0, no matter what)
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
# (please, report bugs and / or send feature requests to daxxar@daxxar.com)
############## ############## ############## ############## ############## ######## #### ## #

use strict;

my $rescan = '/bin/rescan';			# Change if you've moved it / using another rescanner.
my $rmscript = 'rmlog.sh';			# Generates 'rmlog.sh' in /, containing rm -rf "$dir" on all failed rels.
									# Set to '' to disable this feature. ;-)
									# NOTE: You actually need to run this script MANUALLY if you want to rm the releases. ;)

my $zipscan = 1;					# Set to 0 if you do not want to rescan dirs with .zips. :)
my $preservestamp = 1;				# Set to 0 if you do not want to preserve timestamps on dirs.
my $stampfromfile = 0;				# Set to 1 if you want to fetch the timestamp from the first zip/sfv-file in thedir.
									# Useful for people who've run the original script (1.4rc1 or before), and want to regen.
my $printeach = 1;					# Set to 0 if you do not want it to output "PASSED:" and "FAILED:" for each rescan. 

my $onlysort = 0;					# Set to 1 if you only want to resort mp3 releases, and never run rescan.
									# Does not create rmscript. Remember; rescan resorts too!
									# SO ONLY USE THIS FEATURE IF YOU WANT TO SAVE TIME, IF YOU KNOW ALL RELEASES
									# ARE CRC-CHECKED, OR WANT TO SORT SFV-LESS RELEASES!
my $audiosort = '/bin/audiosort';	# This defines what bin we use instead of /bin/rescan if $onlysort = 1. :)

######    NOTICE
#### Below here should not be changed (unless you're hacking this script, or fixing a bug). :)
### If you find a bug, (and perhaps fix it), or have a request for a feature,
## please contact the author, daxxar. He's reachable per IRC 
# (nick daxxar) or mail (daxxar@daxxar.com). Thanks.

my $version = '.4';
print "+ Starting total rescan v1$version by daxxar ^ team pzs-ng.\n";

my $path = shift;
my $glroot = shift || '/glftpd';
$glroot =~ s/(?<!\/)$/\//;

$rmscript = '' if not defined($rmscript) or $onlysort;

if (!defined($path)) {
	print STDERR "- Path to scan not defined, exiting.\n";
	print STDERR "  (syntax: $0 <pattern> [glroot], pattern is relative to glroot, and a standard shell-pattern)\n";
	exit 1;
}


sub isscandir {
	my $dir = shift || die("Need a param for isscandir()\n");
	return 0 if -l $dir;

	if (!opendir(TARGETDIR, $dir)) {
		print STDERR "- Opening directory '$dir' for reading failed, skipping! ($!)\n";
		return 0;
	}
		
	while (($_ = readdir(TARGETDIR))) {
		if (/^\./ || -d "$_") { next; }
		if (!$onlysort && /\.sfv$/i) {
			closedir(TARGETDIR);
			return 1;
		}
		if (!$onlysort && $zipscan && /\.zip$/i) {
			closedir(TARGETDIR);
			return 1;
		}
		if ($onlysort && /\.mp3$/i) {
			closedir(TARGETDIR);
			return 1;
		}
	}

	# In case the dir is without .sfv/.zip/.mp3. :)
	closedir(TARGETDIR);
	return 0;
}

sub rescandir {
	my $dir = shift || die("Need a param for rescandir()\n");
	if (!chdir($dir)) {
		print STDERR "- Changing dir to '$dir' failed, skipping! ($!)\n";
		return 0;
	}

	my $retval;
	if ($onlysort) {
		my $output = `$audiosort`;
	} else  {
		my ($atime, $mtime);
		if ($preservestamp) {
			($atime, $mtime) = (stat( (glob('*.{sfv,diz,zip}'))[0] ))[8, 9] if $stampfromfile;
			($atime, $mtime) = (stat('.'))[8, 9] if not $stampfromfile;
		}

		my $output = `$rescan`;
		my ($passed, $total) = (-1, -1);
		if ($output =~ /Passed ?: ?(\d+)$/m) { $passed = $1; }
		if ($output =~ /Total ?: ?(\d+)$/m) { $total = $1; }
		
		if ($passed == -1 || $total == -1) {
			print STDERR "- ERROR! Output from $rescan on '$dir' was unparseable. (Nonstandard rescan binary?)\n";
			$retval = 0;
		} elsif ($passed == $total) {
			print "+ PASSED: $dir\n" if $printeach;
			$retval = 1;
		} else {
			print "- FAILED: $dir\n" if $printeach;
			if ($rmscript ne '') {
				open(RMLOG, ">>/$rmscript");
				print RMLOG "rm -rf '$glroot$dir'\n";
				close(RMLOG);
			}
			$retval = 0;
		}
		
		utime($atime, $mtime, '.') if $preservestamp;
	}
	chdir('/');

	return $retval;
}

print "+ Changing root for script to '$glroot' and changing dir to '/'.\n";
if ($glroot ne '/' && !chroot($glroot)) {
	print STDERR "- Changing root failed! ($!)\n";
	exit 1;
}
if (!chdir('/')) {
	print STDERR "- WTF? Changing dir to '/' failed! ($!)\n";
	exit 1;
}

while (my $cpath = scalar glob $path) {
	if (! -d $cpath) {
		print STDERR "! Pattern '${glroot}${path}' matches something ('$cpath') that's not a dir (or does not exist)!\n";
		print STDERR "  (syntax: $0 <pattern> [glroot], pattern is relative to glroot, and a standard shell-pattern)\n";
		exit 1;
	}
}


if ($rmscript ne '') {
	print "+ Cleaning rmscript (/$rmscript)\n";
	open(RMLOG, ">/$rmscript");
	print RMLOG "echo '* Starting deletion of failed dirs.. :)'\n";
	close(RMLOG);
	chmod(0755, "/$rmscript");
}


my ($scanneddirs, $gooddirs, $baddirs) = (0, 0, 0);

print "+ Scanning dirs for sfv-files & rescanning.\n" if not $zipscan;
print "+ Scanning dirs for sfv/zip-files & rescanning.\n" if $zipscan;
my @dirs;
while (my $cdir = scalar glob $path) {
	my @dirs = ($cdir);
	while ((my $dir = shift @dirs)) {
		if (!opendir(DIR, $dir)) {
			print STDERR "- Opening directory '$dir' for reading failed, skipping! ($!)\n";
			next;
		}

		while (($_ = readdir(DIR))) {
			my $tdir = "$dir/$_";
			if (/^\./ || ! -d $tdir) { next; }
			unshift(@dirs, "$tdir"); 

			if (isscandir($tdir)) {
				++$scanneddirs;
				if (rescandir($tdir)) {
					++$gooddirs;
				} else {
					++$baddirs;
				}
			}
		}
		closedir(DIR);
	}
}

if (!$scanneddirs) {
	print "! Could not find any dirs containing any SFVs under '$path', exiting.\n" if not $zipscan;
	print "! Could not find any dirs containing any SFVs or ZIPs under '$path', exiting.\n" if $zipscan;
	exit 1;
}

if (!$onlysort) {
	print "+ Good dirs: $gooddirs\n";
	print "!  Bad dirs: $baddirs\n";
	print "+     Total: $scanneddirs\n";
}

if ($rmscript ne '') {
	print "+ Adding 'closing entry' to rmscript ;)\n";
	open(RMLOG, ">>/$rmscript");
	print RMLOG "echo '* All done with deletion! :D'\n";
	close(RMLOG);
}

print "+ Done! :)\n";
