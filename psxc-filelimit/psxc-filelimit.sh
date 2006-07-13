#!/bin/bash

# psxc-filelimit.sh
###################
#
# A small script meant to limit number of files downloaded per ip.
# add the following in glftpd.conf:
#   cscript RETR pre /bin/psxc-filelimit.sh
# also make sure to run this script at given intervals from crontab - this will reset
# the stats, allowing the users to download more:
#   0 0 * * * /glftpd/bin/psxc-filelimit.sh >/dev/null 2>&1
#
# Needed bins: echo cut tr tail grep cat chmod
#
#########################################################################################

## CONFIG ##
############

# Max numbers of files allowed in timeframe.
FILELIMIT=10

# Message to send if limit is exceeded.
MESSAGE="You have exceeded the number of files allowed. To download more, wait 24hours."

# What filetypes should be counted? (don't use * or regexp)
LIMITTYPES="tgz gz tar rar zip sh tcl exe mp3"

# Rootpath for glftpd
GLROOT=/glftpd

# Tempdir, inside /glftpd. The tempdir must be chmod'ed 777
TMPDIR=/tmp

# Word to add before all tempfiles - just leave as is.
PREPEND="psxc-filelimit_"

############
############

VERSION=0.1

[[ "$RATIO" == "" ]] && {
  rm -f ${GLROOT}/${TMPDIR}/${PREPEND}*
  exit 0
}
myhost=$(echo $HOST | cut -d '@' -f 2-)
ftype=$(echo $1 | tr '\.' '\n' | tail -n 1)
totnum=0
[[ ! -z "$(echo "$LIMITTYPES" | grep -i "$ftype")" ]] && {
  [[ -e $TMPDIR/$PREPEND$myhost ]] && totnum=$(cat $TMPDIR/$PREPEND$myhost)
  let totnum=totnum+1
  [[ $totnum -gt FILELIMIT ]] && {
    echo "200 $MESSAGE"
    exit 1
  }
  echo -n $totnum >$TMPDIR/$PREPEND$myhost && chmod 666 $TMPDIR/$PREPEND$myhost
  let fleft=FILELIMIT-totnum
  echo "200 psxc-filelimit v$VERSION: Allowed downloads left: $fleft."
}
exit 0

