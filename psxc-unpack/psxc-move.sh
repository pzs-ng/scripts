#!/bin/bash

# psxc-move v0.1
################

# The logfile to be parsed.
LOGFILE=/glftpd/tmp/psxc-unpack-complete.log

# a tempfile
TMPFILE=/glftpd/tmp/psxc-move.tmp

# Where to copy the release
CPDEST=/glftpd/site/NFS/SHARE_2/_USORTERT/

# Where to move the release after copy
MVDEST=/glftpd/site/SFV/_SLETT/

# The full path to your /glftpd/site
GLSITE="/glftpd/site/"

# The PATH variable
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:/usr/X11R6/bin:/root/bin:/glftpd/bin

# String of subdirs to be ignored.
SUBDIRS="^[Cc][Dd][0-9]$|^[Dd][Vv][Dd][0-9]$|^[Ss][Uu][Bb].$"

# Files/dirs with the following chars will not be moved. This option is required
# if you move a release to a different filesystem that cannot handle the chars.
DENYCHARS="%"

#################################
# code
#set -x -v

:>$TMPFILE
lines=$(wc -l $LOGFILE | tr  ' ' '\n' | grep -v '/' | grep -v "^$")
while [ $lines -gt 0 ]; do
 line="$(cat $LOGFILE | sort | head -n 1 | tr -s '/')"
 let lines=lines-1
 cat $LOGFILE | sort | tr -s '/' | tail -n $lines >$TMPFILE && cat $TMPFILE >$LOGFILE
 [[ -z "echo $line | tr -cd 'a-zA-Z/0-9_" ]] && break
 dateline=$(echo $line | tr ' ' '\n' | grep -v "^$" | grep -v "/" | head -n 1)
 today=$(date "+%s")
 [[ $dateline -gt $today ]] && {
  echo "$line" >>$LOGFILE
  break
 }
 dirline="$(echo $line | cut -d ' ' -f 2-)"
 [[ ! -z "$(basename $dirline | grep -E -- "$SUBDIRS")" ]] && dirline="$(dirname "$dirline")"
 [[ -d "$dirline" && ! -z "$(echo "$dirline" | grep -- "$GLSITE")" ]] && {
  mylines="$(find "$dirline" -type d | sed "s|$(dirname $dirline)||g")"
  IFS="
"
  for myline in $mylines; do
echo   mkdir -pm777 $CPDEST/$myline
echo   mkdir -pm777 $MVDEST/$myline
  done
  mylines="$(find "$dirline" -type f | sed "s|$(dirname $dirline)||g")"
  IFS="
"
  for myline in $mylines; do
echo   cp -p $myline $CPDEST/
echo   cp -p $myline $MVDEST/
  done
echo   rm -fR $dirline

#  cp -fRpn "$dirline" $CPDEST/
#  mv -n "$dirline" $MVDEST/
 }
 lines=$(wc -l $LOGFILE | tr  ' ' '\n' | grep -v '/' | grep -v "^$")
done
exit 0

