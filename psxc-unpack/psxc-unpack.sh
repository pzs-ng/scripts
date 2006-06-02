#!/bin/bash

# psxc-unpack.sh v0.3 (c) psxc//2006
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
# 2. make your zipscript run this script after release is complete.
#    with pzs-ng, add
#      #define complete_script "/bin/psxc-unpack.sh"
#    to zsconfig.h
# 3. add a crontab entry to execute /glftpd/bin/psxc-unpack.sh at certain intervals
#      */5 * * * * /glftpd/bin/psxc-unpack.sh
#
# you can also use this as a site command - fyi
#   site_cmd UNPACK CMD /bin/psxc-unpack.sh
#   custom-unpack 1

# neeed bins:
# unrar ps grep cat awk head ls echo mv tr (nice)

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
DIRS="/site/DVDR /site/XVID"

# the unrar command. remove the 'echo' in front to activate
UNRAR="echo nice -n 20 unrar e"

# rm/delete command. remove the 'echo' in front to activate
RM="echo rm"

# rar filetypes. should be fine as is.
FILETYPES=".[Rr0-9][aA0-9][rR0-9]"

# set this to '1' to make the script run immediatly after release is complete
RUN_NOW=0

# put here a word to use to make the script unpack immediatly - only
# handy if you add this script as a site command. Not case sensitive.
MAGICWORD="now"

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

[[ ! -e $LOGFILE ]] && :>$LOGFILE
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
RDIR=""
[[ -e $GLROOT/$LOGFILE ]] && RDIR=$GLROOT
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
  for FNAME in $(ls $RDIR/$DNAME); do
    for FTYPE in $FILETYPES; do
      [[ ! -z "$(echo $FNAME | grep $FTYPE)" ]] && EXTRACTNAME=$FNAME
    done
    [[ ! -z "$EXTRACTNAME" ]] && break
  done
  grep -v "$DNAME" $RDIR/$LOGFILE > $RDIR/$LOGFILE.tmp
  mv $RDIR/$LOGFILE.tmp $RDIR/$LOGFILE
  [[ ! -z "$EXTRACTNAME" ]] && {
    cd $RDIR/$DNAME
    $UNRAR $EXTRACTNAME
    [[ $? -eq 0 ]] && {
      for FNAME in $(ls $RDIR/$DNAME); do
        for FTYPE in $FILETYPES; do
          [[ ! -z "$(echo $FNAME | grep -e $FTYPE)" ]] && $RM $FNAME
        done
      done
    }
  }
done
$RM $RDIR/$LOGFILE.pid

