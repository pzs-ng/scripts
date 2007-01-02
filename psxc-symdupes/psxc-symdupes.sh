#!/bin/bash

#############################################################
#
# psxc-symdupes v0.3
# ==================
#
# If same release is found several places, the dupes will
# be removed and a symlink will take its/their place,
# pointing to the "original".
#
#############################################################


# List the sections to search for duplicates - this list
# also represents significance of each sections. Dupes in
# section further down the list is less significant.
# DO NOT END DIRS HERE WITH A SLASH!
SECTIONS="
/glftpd/site/archives/group-archive
/glftpd/site/archives/artists
/glftpd/site/archives/labels
"

# List here what dirs should be excluded. This is not regexp,
# so no need for fancy stuff, or *something*. Just use ^ to
# find something at the beginning of a dirname, and $ to find
# the end.
EXCLUDES="
^\[
^[(]
^\.
^[cC][dD]
^[dD][vV][dD]
^[dD][iI][sS][cCkK]
^NUKED
^[01][1234567890]$
^[01][1234567890]-
^[1234567890][1234567890][1234567890][1234567890]
^[Cc][Oo][Vv][Ee][Rr][Ss]$
^[Jj][Aa][Nn]-
^[Ff][Ee][Bb]-
^[Mm][Aa][Rr]-
^[Aa][Pp][Rr]-
^[Mm][Aa][YyIi]-
^[Jj][Uu][Nn]-
^[Jj][Uu][Ll]-
^[Aa][Uu][Gg]-
^[Ss][Ee][Pp]-
^[Oo][CcKk][Tt]-
^[Nn][Oo][Vv]-
^[Dd][Ee][CcSs]-
^[Uu][Nn][Ss][Oo][Rr][Tt][Ee][Dd]
^[Ss][Aa][Mm][Pp][Ll][Ee]
^[Mm][Oo][Vv][Ii][Ee]
^[Ss][Uu][Bb]$
^[Ss][Uu][Bb][Ss]$
^\_
"

# Where is glftpd/site installed?
GLROOT=/glftpd/site

# Where can i store some tempfiles?
TMPDIR=/tmp

# Where and what name should the final "script" be named?
# This script is generated. You should take a close look to
# make sure it doesn't remove anything you wish to keep. It
# may be the script marks wrong dirs.
# Once that's done, chmod +x it and run it.
DESTFILE=/tmp/dupedel.sh

#################################################################


TMP1=$TMPDIR/symdupes.tmp
TMP2=$TMPDIR/symdupes.tm2
TMP3=$TMPDIR/symdupes.tm3
:>$TMP1
secnum=0

# create the database
echo "Creating a database of dirs ..."
for section in $SECTIONS; do
  find $section/* -type d >$TMP2
  while read mydir; do
    echo "$(basename "$mydir"):$(dirname "$mydir")" >>$TMP1
    echo "$(basename "$mydir")" >>$TMP3
  done < $TMP2
  let secnum=secnum+1
done

# remove EXCLUDES
echo "Removing unwanted cruft according to EXLUDES-setting ..."
for exclude in $EXCLUDES; do
  grep -v "$exclude" $TMP3 >$TMP2
  mv $TMP2 $TMP3
  grep -v "$exclude" $TMP1 >$TMP2
  mv $TMP2 $TMP1
done

# sort the db and find what needs be done.
echo "Sorting the database before starting the 'real' work ..."
sort $TMP3 | uniq -d >$TMP2
[[ -e $TMP2 ]]&& mv $TMP2 $TMP3
while read relline; do
  grep "$relline" $TMP1 >>$TMP2
done < $TMP3
[[ -e $TMP2 ]] && mv $TMP2 $TMP1
rm $TMP3

# let's start the real work
echo "Finding dupes and creating the wipe script ..."
echo "#!/bin/bash" >$DESTFILE
if [ -e $DESTFILE.errors ]; then
  rm -f $DESTFILE.errors
fi
s_total=0
for section in $SECTIONS; do
  s_size=0
  echo "Scanning dupes with base in $section ..."
  while [ $secnum -gt 0 ]; do
    relline="$(grep $section $TMP1 | head -n 1)"
    grep -v "$relline" $TMP1 >$TMP3 && mv $TMP3 $TMP1
    relname="$(echo $relline | cut -d ':' -f 1)"
    if [ "$relname" == "" ]; then
      break
    else
      grep "$relname" $TMP1 >$TMP2
      while read dupe; do
        dupesec="$(echo "$dupe" | cut -d ':' -f 2)"
        secroot="$(echo "$relline" | cut -d ':' -f 2 | sed "s|$GLROOT|/|" | tr -s '/')"
        echo -e "\nif [ -d \"$dupesec/$relname\" -a -d \"$GLROOT/$secroot/$relname\" ]; then\n\trm -fR \"$dupesec/$relname\"\n\tln -s \"$secroot/$relname\" \"$dupesec/$relname\"\nfi" >>$DESTFILE
        
        s_rsiz=$(du -ks "$dupesec/$relname" 2>/dev/null)
        if [ $? -ne 0 ]; then
          echo "Possible problem with $dupesec/$relname" >>$DESTFILE.errors
        else
          s_rsize=$(echo "$s_rsiz" | awk '{print $1}')
          let s_size=s_size+s_rsize
        fi
      done < $TMP2
      grep -v "$relname" $TMP1 >$TMP2
      mv $TMP2 $TMP1
    fi
  done
  let secnum=secnum-1
  echo "Done with section $section - potential freespace: ${s_rsize}KB."
  let s_total=s_total+s_rsize
done
[[ -e $TMP1 ]]&& rm $TMP1
[[ -e $TMP2 ]]&& rm $TMP2
[[ -e $TMP3 ]]&& rm $TMP3
t_dirs=$(grep "rm " $DESTFILE | sort | uniq | wc -l)
echo "Done. Total potential freespace: ${s_size}KB in $t_dirs dirs."
echo -n "\nPlease adjust $DESTFILE and make sure all is okay."
echo "When done, chmod +x $DESTFILE and run it."
if [ -e $DESTFILE.errors ]; then
  echo "Some errors occured when scanning. Check $DESTFILE.errors for more info."
fi

