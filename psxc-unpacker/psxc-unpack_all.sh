#!/bin/bash

# psxc-unpack_all.sh v0.3 (c) psxc//2006
########################################
#
# This here is an addon to psxc-unpack.sh.
# It's purpose is to make it possible to scan and unpack recursively.
# Should probably only be used as a shell script
#
# Needed bins: echo find tr grep 

#####################################################
# CONFIGURATION
#####################################################

# glftpd's rootdir
GLROOT=/glftpd

# your PATH variable
PATH=$GLROOT/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/libexec

# your *Complete* dir/file looks like...
COMPLETE_DIR="*\[*\]*COMPLETE*\[*\]"

# nuked dir style
NUKED_DIRS="\[NUKED\]*"

# what dirs to search
SEARCH_DIRS="/site/DIVX /site/DVDR"

# path to psxc-unpack.sh
UNPACK=/bin/psxc-unpack.sh

# where to log paths found
LOGFILE=/tmp/psxc-unpack.log

# run psxc-unpack after scan is complete? (1=yes, 0=no)
RUN_NOW=1

# magic word (only needed if used as a site command or within
# chroot, and RUN_NOW=1.)
MAGIC_WORD="now"

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

init_dir=$(echo $SEARCH_DIRS | tr ' ' '\n' | head -n 1)
RDIR=""
[[ -d $GLROOT/$init_dir ]] && RDIR=$GLROOT
for sdir in $SEARCH_DIRS; do
  echo "scanning $sdir ...."
  for fdir in $RDIR/$sdir/*; do
    [[ "$(find $fdir -name $COMPLETE_DIR)" != "" ]] && echo $fdir | tr -s '/' | grep -v $NUKED_DIRS >>$RDIR/$LOGFILE
  done
done
echo "done scanning."
[[ $RUN_NOW -ne 0 ]] && {
  echo "running psxc-unpack.sh - this could take a while."
  $RDIR/$UNPACK $MAGIC_WORD
  echo "done."
}

