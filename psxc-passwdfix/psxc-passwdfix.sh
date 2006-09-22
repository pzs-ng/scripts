#!/bin/bash

# psxc-passwdfix.sh v0.1
# ----------------------
# A simple script to help fix broken/lost group and/or passwd file(s).
#
##

# Where to place the new group/passwd files - /tmp is a good place, so you can
# look them over before copying to the correct place
GROUPFILE=/tmp/group
PASSWDFILE=/tmp/passwd

# Where are the userfiles? These will not be touched, only used as a source to
# read data from.
USERFILES=/glftpd/ftp-data/users

# What hash to use for the ressurrected passwdfile - the default is a hash for
# "glftpd" - ie, all users will have the passwd "glftpd".
# Remember to escape  (``\'') the dollar (``$'') signs, like so: "\$"
PASSWDHASH="\$c8aa2099\$89be575337e36892c6d7f4181cad175d685162ad"

###### END OF CONFIG ######

uid=100
gid=100
:>$GROUPFILE
:>$PASSWDFILE
for gfile in $(ls -1f $USERFILES | grep -v "^default\.") ; do
  gname="$(grep ^GROUP $USERFILES/$gfile | head -n 1 | cut -d ' ' -f 2)"
  mygid="$(grep "^$gname:" $GROUPFILE | cut -d ':' -f 2)"
  [[ "$mygid" == "" && "$gname" ]] && {
    mygid=$gid
    let gid=gid+100
    echo "$gname:$gname:$mygid:RESSURRECTED" >>$GROUPFILE
  }
  echo $gfile:${PASSWDHASH}:$uid:$gid:0:/site:/bin/false >>$PASSWDFILE
  let uid=uid+100
done
for gfile in $(ls -1f $USERFILES | grep -v "^default\.") ; do
  for gname in $(grep ^GROUP $USERFILES/$gfile | cut -d ' ' -f 2) ; do
    [[ "$gname" && "$(grep "^$gname:" $GROUPFILE | cut -d ':' -f 2)" == "" ]] && {
      let gid=gid+100
      echo "$gname:$gname:$gid:RESSURRECTED" >>$GROUPFILE
    }
  done
done

