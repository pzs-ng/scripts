#!/bin/bash

# This must be set correctly.
conf=./psxc-free.conf

## code part below
####################################################################

logsimpledir()
{
  if [[ -d $1 ]]; then
    mdate=$($MDATE $1 $2)
    dsize=$(du -sk $1 | awk '{print $1}')
    sectionsize[$secnum]=$(expr ${sectionsize[$secnum]} + $dsize)
    echo -e "$mdate\t$dsize\t$1\t$secnum" >>$TEMPFILE1
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
      #rm -fR $1
      echo "$(date "+%a %b %e %T %Y") PSXCFREE: {$(echo /$1 | sed "s|$GLROOT||" | tr -s '/')} {$2}" #>> $GLLOG
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

while [ "$devicename" ]; do
  :>$TEMPFILE1
  :>$TEMPFILE2
  # filling vars
  eval minfree=\$MINFREE_$devnum
  eval setfree=\$SETFREE_$devnum
  eval dirs=\$DIRS_$devnum
  eval excludes=\$EXCLUDES_$devnum
  excludes=$(echo "$excludes" | tr ' ' '|')
  eval daysback=\$DAYSBACK_$devnum

  # testing to see if enough space is availible on device
  freespace=$(df -Pm $devicename | grep ^/ | awk '{print $4}')
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
  secnum=0
  for modname in $dirs; do
    let secnum=secnum+1
    sectionsize[$secnum]=0
    if [[ $(echo $modname | grep ":") ]]; then
      dname=$(echo $modname | cut -d ":" -f 1)
    else
      dname=$modname
    fi
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
  secnum=0
  for modname in $dirs; do
    let secnum=secnum+1
    if [[ ! -z "$(echo $modname | grep ":")" ]]; then
      dname=$(echo $modname | cut -d ":" -f 1)
      ssize=$(echo $modname | cut -d ":" -f 2)
      if [[ $(echo $ssize | grep -i "G") ]]; then
        dsize=$(echo $ssize | tr -cd '0-9')
        let dsize=dsize*1024
      elif [[ $(echo $ssize | grep -i "T") ]]; then
        dsize=$(echo $ssize | tr -cd '0-9')
        let dsize=dsize*1024*1024
      elif [[ $(echo $ssize | grep -i "%") ]]; then
        tsize=$(df -Pm $devicename | grep ^/ | awk '{print $2}')
        dsize=$(echo $ssize | tr -cd '0-9')
        let dsize=tsize*dsize/100
      else
        dsize=$(echo $ssize | tr -cd '0-9')
      fi
    else
      dname=$modname
      dsize=0
    fi
    let dsize=dsize*1024
    if [[ $dsize -ne 0 && $dsize -lt ${sectionsize[$secnum]} ]]; then
      while read -a readline; do
        if [[ $secnum -eq ${readline[3]} ]]; then
          freeupspace ${readline[2]} ${readline[1]}
          if [[ "$TESTRUN" == "YES" || ! -e ${readline[2]} ]]; then
            let freespace=freespace+${readline[1]}/1024
            let sectionsize[$secnum]=${sectionsize[$secnum]}-${readline[1]}
            if [[ $freespace -gt $setfree ]]; then
              break
            fi
            if [[ $dsize -gt ${sectionsize[$secnum]} ]]; then
              break
            fi
          fi
        fi
      done < $TEMPFILE2
    fi
  done
  # free more space if avail space is not yet reached
  if [[ $freespace -le $setfree ]]; then
    while read -a readline; do
      freeupspace ${readline[2]} ${readline[1]}
      if [[ "$TESTRUN" == "YES" || ! -e ${readline[2]} ]]; then
        let freespace=freespace+${readline[1]}/1024
        if [[ $freespace -gt $setfree ]]; then
          break
        fi
      fi
    done < $TEMPFILE2
  fi
  # end loop - continue to next device
  let devnum=devnum+1
  eval devicename=\$DEVICENAME_$devnum
done

