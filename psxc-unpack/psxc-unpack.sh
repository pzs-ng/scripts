#!/bin/bash

# psxc-unpack.sh v0.9 (c) psxc//2006
####################################
#
# This simple little thingy extracts files in a dir and removes the
# archive files afterwards. You can use this two ways - either extract
# files right after a release is complete, or crontab it. The latter
# is the best way imho.
# the 'nice' command should be used to keep unrar from hogging too much cpu -
# see UNRAR (below)
#
# NOTICE: This script does not scan recursively - to make that possible, use
#         psxc-unpack_all.sh
#
######################################
#
# installation:
# 1. copy psxc-unpack.sh to /glftpd/bin
# 2. make sure the /glftpd/tmp dir exists, and is world read/writable:
#      mkdir -p -m777 /glftpd/tmp
# 3. make your zipscript run this script after release is complete.
#    with pzs-ng, add
#      #define complete_script "/bin/psxc-unpack.sh"
#    to zsconfig.h
# 4. add a crontab entry to execute /glftpd/bin/psxc-unpack.sh at certain intervals
#      */5 * * * * /glftpd/bin/psxc-unpack.sh
#
# you can also use this as a site command - fyi
#   site_cmd UNPACK EXEC /bin/psxc-unpack.sh
#   custom-unpack 1

# neeed bins:
# unrar ps grep cat awk head ls echo mv tr chmod wc basename tr (nice)

#####################################################
# CONFIGURATION
#####################################################

# PATH variable - should be fine as is.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/libexec:/usr/libexec

# glftpd's root dir
GLROOT=/glftpd

# path to external conf - will override the settings below if found
# this path is within chroot, so don't add /glftpd in front.
UNPACK_CONF=/etc/psxc-unpack.conf

# glftpd's site dir
SITEDIR=/site

# where our logfile is located - path is within chroot so don't
# put /glftpd in front of this.
LOGFILE=/tmp/psxc-unpack.log

# glftpd's logfile (within chroot) - used for announces.
GLLOG=/ftp-data/logs/glftpd.log

# in what dirs should this script be executed?
DIRS="/site/XVID /site/DVDR"

# the unrar command. remove the 'echo' in front to activate
# also check the man page for unrar.
UNRAR="echo nice -n 20 unrar e -p- -c- -cfg- -o- --"

# rm/delete command. remove the 'echo' in front to activate
RM="echo rm"

# rmdir command - used to delete empty subdirs. remove the 'echo' in front
# to activate. WARNING! Be careful!
RMDIR="echo rm -fR"

# rar filetypes. should be fine as is.
FILETYPES="\.[Rr0-9][aA0-9][rR0-9]$"

# subdirs. should be fine as is.
SUBDIRS="^[Cc][Dd][0-9a-zA-Z]$ ^[Dd][Vv][Dd][0-9a-zA-Z]$ ^[Ss][Uu][Bb][Ss]*$"

# how your completedirs look like. (This is regexp style, so keep the .*)
COMPLETEDIR=".*\[*\].*[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee].*\[*\].*"

# this variable holds a list of files/dirs to remove if extraction was complete.
# (not regexp style, so slightly different.) separate with a space.
# default setting removes the complete bar, sample dir and dot-files (like .message)
RMFILES="*\[*\]*[Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee]*\[*\]* [Ss][Aa][Mm][Pp][Ll][Ee] \.[a-zA-Z0-9]*"

# set this to '1' to make the script run immediatly after release is complete
RUN_NOW=0

# put here a word to use to make the script unpack immediatly - only
# handy if you add this script as a site command. Not case sensitive.
# The site command will then be 'site unpack now' to extract immediatly.
MAGICWORD="now"

# If you wish to remove write-rights of the dirs after extraction, set this
# variable to 1.
CHMOD_DIRS=1

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

init_dir=$(echo $DIRS | tr ' ' '\n' | head -n 1)
RDIR=""
[[ -d $GLROOT/$init_dir ]] && RDIR=$GLROOT
[[ -e $RDIR/$UNPACK_CONF ]] && source $RDIR/$UNPACK_CONF
[[ ! -e $RDIR/$LOGFILE ]] && :>$RDIR/$LOGFILE && chmod 666 $RDIR/$LOGFILE
[[ ! -w $RDIR/$LOGFILE ]] && echo "HELP! UNABLE TO LOG DIRS! CHECK PERMS" && exit 1
[[ ! -e $GLROOT/$LOGFILE && -e $SITEDIR ]] && {
  for DNAME in $DIRS; do
    [[ ! -z "$(echo $PWD | grep $DNAME)" ]] && {
      found=1
       break
    }
  done
  [[ $found -eq 1 ]] && echo "$PWD" >>$RDIR/$LOGFILE
}
[[ "$(echo "$MAGICWORD" | tr 'A-Z' 'a-z')" == "$(echo "$1" | tr 'A-Z' 'a-z')" ]] && RUN_NOW=1
[[ $RUN_NOW -ne 1 && ! -e $GLROOT/$LOGFILE && -e $SITEDIR ]] && exit 0
[[ -z "$(cat $RDIR/$LOGFILE)" ]] && rm $RDIR/$LOGFILE && exit 0
[[ -e $RDIR/$LOGFILE.pid ]] && {
  oldpid=$(cat $RDIR/$LOGFILE.pid)
  for pid in $(ps ax | awk '{print $1}'); do
    [[ $pid -eq $oldpid ]] && exit 0
  done
}
echo $$ >$RDIR/$LOGFILE.pid && chmod 666 $RDIR/$LOGFILE.pid
:>$RDIR/$LOGFILE.complete && chmod 666 $RDIR/$LOGFILE.complete
while [ 1 ]; do
  :>$RDIR/$LOGFILE.tmp && chmod 666 $RDIR/$LOGFILE.tmp
  [[ -z "$(cat $RDIR/$LOGFILE)" ]] && break
  DNAME=$(head -n 1 $RDIR/$LOGFILE)
  [[ ! -d $RDIR/$DNAME ]] && {
    grep -v "$DNAME$" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
    mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
    continue
  }
  while [ 2 ]; do
    :>$RDIR/$LOGFILE.tmp && chmod 666 $RDIR/$LOGFILE.tmp
    EXTRACTNAME=""
    [[ ! -e $RDIR/$DNAME ]] && break
    ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp
    cd $RDIR/$DNAME
    while read -a FNAME; do
      for FTYPE in $FILETYPES; do
        [[ ! -z "$(echo $FNAME | grep $FTYPE)" ]] && EXTRACTNAME=$FNAME
      done
      [[ ! -z "$EXTRACTNAME" ]] && {
        archive_name=""
        skip_archive=1
        for archive_name in $(unrar lb $EXTRACTNAME); do
          [[ ! -e $archive_name ]] && skip_archive=0
        done
        [[ $skip_archive -eq 1 ]] && $RM $EXTRACTNAME && EXTRACTNAME=""
        [[ $skip_archive -ne 1 ]] && break
      }
    done < $RDIR/$LOGFILE.tmp
    rm $RDIR/$LOGFILE.tmp
    :>$RDIR/$LOGFILE.tmp && chmod 666 $RDIR/$LOGFILE.tmp
    grep -v "$DNAME$" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
    mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
    [[ -z "$EXTRACTNAME" ]] && break
    SMATCH=0
    for SUBDIR in $SUBDIRS; do
      [[ ! -z "$(basename $DNAME | grep -e "$SUBDIR")" ]] && SMATCH=1 && break
    done
    [[ $SMATCH -eq 1 ]] && $UNRAR "$EXTRACTNAME" ../ || $UNRAR "$EXTRACTNAME"
    RET=$?
    [[ $RET -eq 0 ]] && {
      echo $RDIR/$DNAME >>$RDIR/$LOGFILE.complete
      ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp && chmod 666 $RDIR/$LOGFILE.tmp
      DELME=""
      while read -a FNAME; do
        [[ ! -z "$(echo $FNAME | grep -e "\.[Ss][Ff][Vv]$")" && -e $FNAME ]] && {
          [[ ! -z "$(grep -ir "$EXTRACTNAME" $FNAME)" ]] && {
            for DELME in $(cat $FNAME | grep -v "^;"); do
              [[ -f $(find ./ -iname $DELME) ]] && $RM $(find ./ -iname $DELME)
            done
            $RM $FNAME && break
          }
        }
      done < $RDIR/$LOGFILE.tmp
      rm $RDIR/$LOGFILE.tmp
      [[ -z "$DELME" ]] && {
        num_dots=$(echo $EXTRACTNAME | tr -cd '\.' | wc -c | tr -cd '0-9')
        while [ $num_dots -gt 0 ]; do
          partial="$(echo $EXTRACTNAME | cut -d '.' -f 1-$num_dots)"
          [[ "$partial" =~ "[Pp][Aa][Rr][Tt][0-9]*" || "$partial" =~ "[Rr0-9][Aa0-9][Rr0-9]$" ]] || break
          let num_dots-=1
        done
        [[ $num_dots -gt 0 ]] && {
          $RM ./$partial.[Pp][Aa][Rr][Tt]*.[Rr][Aa][Rr]
          $RM ./$partial.[Rr0-9][Aa0-9][Rr0-9]
        }
      }
      [[ ! -z "$RMFILES" ]] && {
        for DELME in $RMFILES; do
          $RMDIR ./$DELME
        done
      }
      [[ ! -e $RDIR/$DNAME ]] && break
      [[ $(ls -1 $RDIR/$DNAME | grep -v "^\ " | grep -v "^\." | grep -v "$COMPLETEDIR" | wc -l) -eq 0 ]] && $RMDIR $RDIR/$DNAME
    }
    [[ $RET -ne 0 ]] && echo "Error in archive $RDIR/$DNAME/$EXTRACTNAME - skipping this dir." && break
    [[ ! -z "$(echo $RM | grep "echo")" ]] && echo "running in testmode - unable to test for more than one release in the dir w/o going into endless loop. breaking." && break
  done
  [[ ! -z "$GLLOG" ]] && echo "$(date "+%a %b %e %T %Y") PSXCUNPACK: {$DNAME}" >>$RDIR/$GLLOG
done
[[ $CHMOD_DIRS -eq 1 && $RET -eq 0 ]] && {
  while read -a CDIR; do
    [[ -d $CDIR ]] && chmod 555 $CDIR
  done < $RDIR/$LOGFILE.complete
}
[[ -e $RDIR/$LOGFILE ]] && rm $RDIR/$LOGFILE
[[ -e $RDIR/$LOGFILE.tmp ]] && rm $RDIR/$LOGFILE.tmp
[[ -e $RDIR/$LOGFILE.complete ]] && rm $RDIR/$LOGFILE.complete
[[ -e $RDIR/$LOGFILE.pid ]] && rm $RDIR/$LOGFILE.pid

