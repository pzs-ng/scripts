#!/bin/bash

# psxc-unpack.sh v0.7 (c) psxc//2006
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
# unrar ps grep cat awk head ls echo mv tr chmod (nice)

#####################################################
# CONFIGURATION
#####################################################

# PATH variable - should be fine as is.
PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/local/libexec:/usr/libexec

# glftpd's root dir
GLROOT=/glftpd

# glftpd's site dir
SITEDIR=/site

# where our logfile is located - path is within chroot so don't
# put /glftpd in front of this.
LOGFILE=/tmp/psxc-unpack.log

# in what dirs should this script be executed?
DIRS="/site/XVID /site/DVDR"

# the unrar command. remove the 'echo' in front to activate
# also check the man page for unrar - you may want to use
# 'unrar x' instead of 'unrar e'.
UNRAR="echo nice -n 20 unrar e -p- -c- -cfg- --"

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
[[ ! -e $RDIR/$LOGFILE ]] && :>$RDIR/$LOGFILE && chmod 666 $RDIR/$LOGFILE
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
[[ -z "$(cat $RDIR/$LOGFILE)" ]] && exit 0
[[ -e $RDIR/$LOGFILE.pid ]] && {
  oldpid=$(cat $RDIR/$LOGFILE.pid)
  for pid in $(ps ax | awk '{print $1}'); do
    [[ $pid -eq $oldpid ]] && exit 0
  done
}
echo $$ >$RDIR/$LOGFILE.pid
:>$RDIR/$LOGFILE.complete
while [ 1 ]; do
  [[ -z "$(cat $RDIR/$LOGFILE)" ]] && break
  DNAME=$(head -n 1 $RDIR/$LOGFILE)
  [[ ! -d $RDIR/$DNAME ]] && {
    grep -v "$DNAME$" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
    mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
    continue
  }
  while [ 2 ]; do
    EXTRACTNAME=""
    [[ ! -e $RDIR/$DNAME ]] && break
    ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp
    cd $RDIR/$DNAME
    while read -a FNAME; do
      for FTYPE in $FILETYPES; do
        [[ ! -z "$(echo $FNAME | grep $FTYPE)" ]] && EXTRACTNAME=$FNAME
      done
      [[ ! -z "$EXTRACTNAME" ]] && {
        [[ -e "$(unrar lb $EXTRACTNAME | head -n 1)" ]] && {
          $RM $EXTRACTNAME && EXTRACTNAME=""
        } || { break
        }
      }
    done < $RDIR/$LOGFILE.tmp
    rm $RDIR/$LOGFILE.tmp
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
      ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp
      while read -a FNAME; do
        [[ ! -z "$(echo $FNAME | grep -e "\.[Ss][Ff][Vv]$")" && -e $FNAME ]] && {
          [[ ! -z "$(grep -ir "$EXTRACTNAME" $FNAME)" ]] && {
            for DELME in $(cat $FNAME | grep -v "^;"); do
              [[ -f $DELME ]] && $RM $DELME
            done
            $RM $FNAME && break
          }
        }
      done < $RDIR/$LOGFILE.tmp
      rm $RDIR/$LOGFILE.tmp
      [[ ! -e $RDIR/$DNAME ]] && break
      [[ $(ls -1 $RDIR/$DNAME | grep -v "^\ " | grep -v "^\." | grep -v "$COMPLETEDIR" | wc -l) -eq 0 ]] && $RMDIR $RDIR/$DNAME
    }
    [[ $RET -ne 0 ]] && echo "Error in archive $RDIR/$DNAME/$EXTRACTNAME - skipping this dir." && break
    [[ ! -z "$(echo $RM | grep "echo")" ]] && echo "running in testmode - unable to test for more than one release in the dir w/o going into endless loop. breaking." && break
  done
done
rm $RDIR/$LOGFILE
rm $RDIR/$LOGFILE.pid
[[ $CHMOD_DIRS -eq 1 ]] && {
  while read -a CDIR; do
    [[ -d $CDIR ]] && chmod 555 $CDIR
  done < $RDIR/$LOGFILE.complete
}
rm $RDIR/$LOGFILE.complete

