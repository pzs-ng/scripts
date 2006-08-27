#!/bin/bash

# psxc-unpack_all.sh v1.1 (c) psxc//2006
########################################
#
# This here is an addon to psxc-unpack.sh.
# It's purpose is to make it possible to scan and unpack recursively.
# Should probably only be used as a shell script
#
# Needed bins: echo find tr grep sed

#####################################################
# CONFIGURATION
#####################################################

# your PATH variable
PATH=$GLROOT/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/libexec

# glftpd's rootdir
GLROOT=/glftpd

# path to external conf - will override the settings below if found
# this path is within chroot, so don't add /glftpd in front.
UNPACK_CONF=/etc/psxc-unpack.conf

# your *Complete* dir/file looks like... 
COMPLETE_DIR="*\[*\]*[-][ ][Cc][Oo][Mm][Pp][Ll][Ee][Tt][Ee]*\[*\]*"

# nuked dir style
NUKED_DIRS="\[NUKED\]*"

# what dirs to search - IMPORTANT!!!
SEARCH_DIRS="/site/XVID /site/DVDR"

# path to psxc-unpack.sh
UNPACK=/bin/psxc-unpack.sh

# where to log paths found
LOGFILE=/tmp/psxc-unpack.log

# run psxc-unpack after scan is complete? (1=yes, 0=no)
RUNNOW=1

# magic word (only needed if used as a site command or within
# chroot, and RUNNOW=1.)
MAGICWORD="now"

################################################################
# CODE BELOW - PLEASE IGNORE
################################################################

RDIR=""
[[ -d $GLROOT/site ]] && RDIR=$GLROOT
[[ -e $RDIR/$UNPACK_CONF ]] && source $RDIR/$UNPACK_CONF
RDIR=""
init_dir=$(echo $SEARCH_DIRS | tr ' ' '\n' | head -n 1)
[[ -d $GLROOT/$init_dir ]] && RDIR=$GLROOT
[[ ! -e $RDIR/$LOGFILE ]] && :>$RDIR/$LOGFILE && chmod 666 $RDIR/$LOGFILE
for sdir in $SEARCH_DIRS; do
  echo -e "\nscanning $sdir ...."
  for fdir in $RDIR/$sdir/*; do
    find "$fdir" -name "$COMPLETE_DIR" >$RDIR/$LOGFILE.tmp && chmod 666 $RDIR/$LOGFILE.tmp
    while read -a "mdir"; do
      echo $(dirname "$mdir") | tr -s '/' | sed "s|$RDIR||" | grep -v "$NUKED_DIRS" >>$RDIR/$LOGFILE
      echo "FOUND: $(dirname "$mdir" | tr -s '/' | grep -v "$NUKED_DIRS" | sed "s|$RDIR||" )"
    done < $RDIR/$LOGFILE.tmp
    rm $RDIR/$LOGFILE.tmp
  done
done
echo "done scanning."
[[ $RUNNOW -ne 0 ]] && {
  echo "running psxc-unpack.sh - this could take a while."
  $RDIR/$UNPACK $MAGICWORD
  echo "done."
}

