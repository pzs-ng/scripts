#!/bin/bash

# psxc-unpack.sh v0.5 (c) psxc//2006
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

# rar filetypes. should be fine as is.
FILETYPES="\.[Rr0-9][aA0-9][rR0-9]$"

# set this to '1' to make the script run immediatly after release is complete
RUN_NOW=0

# put here a word to use to make the script unpack immediatly - only
# handy if you add this script as a site command. Not case sensitive.
# The site command will then be 'site unpack now' to extract immediatly.
MAGICWORD="now"

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

init_dir=$(echo $DIRS | tr ' ' '\n' | head -n 1)
[[ -d $GLROOT/$init_dir ]] && RDIR=$GLROOT
[[ ! -e $RDIR/$LOGFILE ]] && :>$RDIR/$LOGFILE && chmod 666 $RDIR/$LOGFILE
[[ ! -e $GLROOT/$LOGFILE && -e $SITEDIR ]] && {
  for DNAME in $DIRS; do
    [[ ! -z "$(echo $PWD | grep $DNAME)" ]] && {
      found=1
       break
    }
  done
  [[ $found -eq 1 ]] && echo "$PWD" >>$LOGFILE
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
while [ 1 ]; do
  [[ -z "$(cat $RDIR/$LOGFILE)" ]] && break
  EXTRACTNAME=""
  DNAME=$(head -n 1 $RDIR/$LOGFILE)
  [[ ! -d $RDIR/$DNAME ]] && {
    grep -v "$DNAME" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
    mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
    continue
  }
  ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp
  while read -a FNAME; do
    for FTYPE in $FILETYPES; do
      [[ ! -z "$(echo $FNAME | grep $FTYPE)" ]] && EXTRACTNAME=$FNAME
    done
    [[ ! -z "$EXTRACTNAME" ]] && break
  done < $RDIR/$LOGFILE.tmp
  rm $RDIR/$LOGFILE.tmp
  grep -v "$DNAME" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
  mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
  [[ ! -z "$EXTRACTNAME" ]] && {
    cd $RDIR/$DNAME
    $UNRAR "$EXTRACTNAME"
    [[ $? -eq 0 ]] && {
      ls -1 $RDIR/$DNAME >$RDIR/$LOGFILE.tmp
      while read -a FNAME; do
        for FTYPE in $FILETYPES; do
          [[ ! -z "$(echo $FNAME | grep -e $FTYPE)" && -e $FNAME ]] && $RM $FNAME && SNAME=$FNAME
        done
      done < $RDIR/$LOGFILE.tmp
      while read -a FNAME; do
        [[ ! -z "$(echo $FNAME | grep -e "\.[Ss][Ff][Vv]$")" && -e $FNAME ]] && {
          [[ ! -z "$(grep -r $SNAME $FNAME)" ]] && $RM $FNAME && break
        }
      done < $RDIR/$LOGFILE.tmp
      rm $RDIR/$LOGFILE.tmp
    }
  }
done
rm $RDIR/$LOGFILE
rm $RDIR/$LOGFILE.pid

