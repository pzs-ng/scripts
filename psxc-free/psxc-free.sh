#!/bin/bash

# This must be set correctly.
conf=./psxc-free.conf

## code part below

logsimpledir()
{
  if [[ -d $1 ]]; then
    mdate=$($MDATE $1 $2)
    dsize=$(du -sk $1 | awk '{print $1}')
    echo -e "$mdate\t$dsize\t$1" >>$TEMPFILE1
  fi
}

logsubdir()
{
  for plaindir in $1/; do
    logsimpledir $plaindir $2
  done
}

logsubsubdir()
{
  for subdir in $1/*; do
    for plaindir in $subdir/; do
      logsimpledir $plaindir $2
    done
  done
}

logdir()
{
   tempvar=$1
   tempvar=${tempvar%/\*}
  if [[ "$tempvar" != "$1" ]]; then
    logsubsubdir $tempvar
  else
    logsubdir $1 $2
  fi
}

freeupspace()
{
  if [[ -z "$(basename $1 | grep -E "$excludes")" ]]; then
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "REMOVING $1"
    else
      echo "removing $1"
      rm -fR $1
    fi
  else
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "IGNORING $1"
    fi
  fi
}

source $conf
devnum=1
eval devicename=\$DEVICENAME_$devnum
:>$TEMPFILE1
:>$TEMPFILE2

while [ "$devicename" ]; do
  # filling vars
  eval minfree=\$MINFREE_$devnum
echo $minfree
  eval setfree=\$SETFREE_$devnum
  eval dirs=\$DIRS_$devnum
  eval excludes=\$EXCLUDES_$devnum
  excludes=$(echo "$excludes" | tr ' ' '|')
  eval daysback=\$DAYSBACK_$devnum

  # testing to see if enough space is availible on device
  freespace=$(df -m $devicename | grep ^/ | awk '{print $4}')
  if [[ -z "$freespace" ]]; then
    echo "FAILED! COULD NOT STAT $devicename!"
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
    continue
  fi
  if [[ $freespace -ge $minfree ]]; then
    echo "Enough space availible on $devicename - skipping this device."
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
    continue
  fi

  # availible space is below minimum allowed
  for dname in $dirs; do
    # dated dir structure ?
    dirname=$SITEDIR/$dname
    if [[ $(echo "$dirname" | grep "%") ]]; then
      currdaysback=$daysback
      datedir=0
      while [ $currdaysback -ge 0 ]; do
        if [ "$USEGNUDATE" != "YES" ]; then
          currdatedir=$(date -v-${currdaysback}d +$dirname)
        else
          currdatedir=$(date --date "-${currdaysback} day" +$dirname)
        fi
        if [[ "${currdatedir}" == "${datedir}" ]]; then
          let currdaysback=currdaysback-1
          continue
        fi
        datedir=$currdatedir
        logdir "$currdatedir" $currdaysback
        let currdaysback=currdaysback-1
      done
    else
      # normal dir structure.
      logdir "$dirname"
    fi
  done

  # now we have a list of dirs with dates and sizes. let's find out what we need to remove.
  sort $TEMPFILE1 >$TEMPFILE2
  TMPIFS="$IFS"
  IFS="
"
  for readline in $(cat $TEMPFILE2); do
    freeupspace $(echo $readline | awk '{print $3}')
    if [[ "$TESTRUN" == "YES" || ! -e $(echo $readline | awk '{print $3}') ]]; then
      let freespace=freespace+$(echo $readline | awk '{print $2}')/1024
      if [[ $freespace -gt $setfree ]]; then
        break
      fi
    fi
  done
  IFS="$TMPIFS"
  # end loop - continue to next device
  let devnum=devnum+1
  eval devicename=\$DEVICENAME_$devnum
done

