#!/bin/bash

# A simple site command to start the move script.
# Add it in the default way.

GLROOT=/glftpd
GLSITE=/site
LOGFILE=/tmp/psxc-unpack-complete.log

#code

[[ ! -w $LOGFILE ]] && {
 echo "Uhu. Check config. (can't write to logfile?)"
 exit 1
}
[[ -z "$1" ]] && {
 echo "Uhu. You need to specify what to move."
 exit 1
}
echo "$(date +%s) $GLROOT/$PWD/$@" | tr -s '/' >>$LOGFILE
echo "Success! $PWD/$@ will be moved." | tr -s '/' | sed "s|$GLSITE||"
exit 0

