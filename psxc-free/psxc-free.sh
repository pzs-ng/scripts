#!/bin/bash
# This must be set correctly.
CONF=/glftpd/etc/psxc-free.sh

## code part below
####################################################################

logsimpledir()
{
  if [[ -d $1 ]]; then
    mdate=$($MDATE $1 $2)
    dsize=$(du -skxP $1 | awk '{print $1}')
    sectionsize[$secnum]=$(expr ${sectionsize[$secnum]} + $dsize)
    echo -e "$mdate\t$dsize\t$1\t$secnum\t$devnum" >>$TEMPFILE1
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
    if [[ "$g_archive" == "YES" ]]; then
      if [[ "${4}" != "NULL" ]]; then
        echo -e "$1\t$4" >>$TEMPFILE3
        if [[ "$TESTRUN" != "YES" ]]; then
          echo "$(date "+%a %b %e %T %Y") PSXCFREE_A: {$(echo /$1 | sed "s|$GLROOT||" | tr -s '/' | sed "s|/$||")} {$2}" >> $GLLOG
        else
          echo "DEVICE $devicename: MARKING $1 - FREEING ${2}M"
        fi
        let freespace[$devnum]=${freespace[$devnum]}+${2}/1024
        let freespace[${5}]=${freespace[${5}]}-${2}/1024
        if [[ "$3" != "NULL" ]]; then
          let sectionsize[$secnum]=${sectionsize[$secnum]}-${2}
        fi
      fi
    else
      delfile=$1
      while read -a writeline; do
        if [[ "${writeline[0]}" == "$delfile" ]]; then
          unset delfile
          break
        fi
      done < $TEMPFILE3
      if [[ ! -z "$delfile" ]]; then
        if [[ "$TESTRUN" != "YES" ]]; then
          echo "$(date "+%a %b %e %T %Y") PSXCFREE: {$(echo /$1 | sed "s|$GLROOT||" | tr -s '/' | sed "s|/$||")} {$2}" >> $GLLOG
          rm -fR $delfile
        else
          echo "DEVICE $devicename: REMOVING $1 - FREEING ${2}M"
        fi
        let freespace[$devnum]=${freespace[$devnum]}+${2}/1024
        if [[ "$3" != "NULL" ]]; then
          let sectionsize[$secnum]=${sectionsize[$secnum]}-${2}
        fi
      fi
    fi
  else
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "DEVICE $devicename: IGNORING $1"
    fi
  fi
}

# VERSION
version=0.3

# Find and read conf
CONF1=$PWD/$0
CONF2=$PWD/../etc/$0
if [[ -e ${CONF1/.sh/.conf} ]]; then
  source ${CONF1/.sh/.conf}
elif [[ -e ${CONF2/.sh/.conf} ]]; then
  source ${CONF2/.sh/.conf}
else
  if [[ -e ${CONF} ]]; then
    source $CONF
  else
    echo "ERROR! COULD NOT FIND psxc-free.conf! Edit the variable CONF in $0 to fix!"
    exit 1
  fi
fi

devnum=1
eval devicename=\$DEVICENAME_$devnum
if [[ "$TESTRUN" == "YES" ]]; then
  echo -e "$(date "+%a %b %e %T %Y") PSXC-FREE v${version} started.\n"
fi
TEMPFILE1=$TEMPDIR/psxc-free.tx1
TEMPFILE2=$TEMPDIR/psxc-free.tx2
TEMPFILE3=$TEMPDIR/psxc-free.tx3
:>$TEMPFILE1
:>$TEMPFILE2
:>$TEMPFILE3
secnum=0
while [ "$devicename" ]; do
  # filling vars
  eval minfree[$devnum]=\$MINFREE_$devnum
  eval setfree[$devnum]=\$SETFREE_$devnum
  eval dirs[$devnum]=\$DIRS_$devnum
  eval daysback[$devnum]=\$DAYSBACK_$devnum
  excludes=$(echo "$EXCLUDES" | tr ' ' '|')
  if [[ -z "${archive[$devnum]}" ]]; then
    archive[$devnum]="NO"
    static_archive[$devnum]="NO"
  fi
  if [[ -z "${static_section[$devnum]}" ]]; then
    static_section[$devnum]="NO"
  fi
  for modname in ${dirs[$devnum]}; do
    if [[ ! -z "$(echo $modname | grep ':')" && ! -z "$(echo $modname | cut -d ":" -f 3)" ]]; then
      archive[$devnum]="YES"
    fi
    if [[ ! -z "$(echo $modname | grep ':')" && ! -z "$(echo $modname | cut -d ":" -f 2)" ]]; then
      static_archive[$devnum]="YES"
    fi
  done

  # testing to see if enough space is availible on device
  freespace[$devnum]=$(df -Pm | grep ^$devicename | awk '{print $4}')
  if [[ -z "${freespace[$devnum]}" ]]; then
    echo "FAILED! COULD NOT STAT $devicename!"
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
    continue
  fi
  if [[ "$TESTRUN" == "YES" ]]; then
    echo "MAPPING SECTIONS ON DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: ${freespace[$devnum]}MB"
  fi
  # should we create today's date?
  for modname in ${dirs[$devnum]}; do
    dirname=$SITEDIR/$(echo $modname | cut -d ":" -f 1)
    if [[ "$CREATEDATE" == "YES" ]]; then
      if [[ ! -z "$(echo "$dirname" | grep "%")" ]]; then
        if [[ ! -e $(date +$dirname) ]]; then
          mkdir -m0777 -p $(date +$dirname)
        fi
      fi
    fi
  done
  if [[ "${archive[$devnum]}" != "YES" ]]; then
    if [[ ${freespace[$devnum]} -ge ${minfree[$devnum]} ]]; then
      if [[ "$TESTRUN" == "YES" ]]; then
        echo "Enough space availible on $devicename - skipping this device."
      fi
      let devnum=devnum+1
      eval devicename=\$DEVICENAME_$devnum
      continue
    fi
  fi

  # availible space is below minimum allowed
  for modname in ${dirs[$devnum]}; do
    if [[ "${archive[$devnum]}" != "YES" ]]; then
      continue
    fi
    let secnum=secnum+1
    if [[ -z "${sectionsize[$secnum]}" ]]; then
      sectionsize[$secnum]=0
    fi
    dirname[$secnum]=$SITEDIR/$(echo $modname | cut -d ":" -f 1)

    # calc sectionsizes
    if [[ ! -z "$(echo $modname | grep ":")" && ! -z "$(echo $modname | cut -d ":" -f 2)" ]]; then
      ssize=$(echo $modname | cut -d ":" -f 2)
      if [[ ! -z $(echo $ssize | grep -i "G") ]]; then
        dsize[$secnum]=$(echo $ssize | tr -cd '0-9')
        let dsize[$secnum]=${dsize[$secnum]}*1024
      elif [[ ! -z $(echo $ssize | grep -i "T") ]]; then
        dsize[$secnum]=$(echo $ssize | tr -cd '0-9')
        let dsize[$secnum]=${dsize[$secnum]}*1024*1024
      elif [[ ! -z $(echo $ssize | grep -i "%") ]]; then
        tsize=$(df -Pm | grep ^$devicename | awk '{print $2}')
        dsize[$secnum]=$(echo $ssize | tr -cd '0-9')
        let dsize[$secnum]=tsize*${dsize[$secnum]}/100
      else
        dsize[$secnum]=$(echo $ssize | tr -cd '0-9')
      fi
    static_section[$devnum]="YES"
    else
      dsize[$secnum]=0
    fi
    let dsize[$secnum]=${dsize[$secnum]}*1024

    # grab archive info
    if [[ ! -z "$(echo $modname | grep ":")" ]]; then
      archdirname[$secnum]=$(echo $modname | cut -d ":" -f 3)
      archdevnum[$secnum]=$(echo $modname | cut -d ":" -f 4)
      if [[ -z "${archdevnum[$secnum]}" ]]; then
        archdevnum[$secnum]=$devnum
      fi
      archive[${archdevnum[$secnum]}]="YES"
    else
     archdirname[$secnum]=""
     archdevnum[$secnum]=0
    fi

    # dated dir structure ?
    if [[ $(echo "${dirname[$secnum]}" | grep "%") ]]; then
      currdaysback=${daysback[$devnum]}
      datedir=0
      while [ $currdaysback -ge 0 ]; do
        if [ "$USEGNUDATE" != "YES" ]; then
          currdatedir=$(date -v-${currdaysback}d +${dirname[$secnum]})
        else
          currdatedir=$(date --date "-${currdaysback} day" +${dirname[$secnum]})
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
      logdir "${dirname[$secnum]}"
    fi
  done
  # end loop - continue to next device
  let devnum=devnum+1
  eval devicename=\$DEVICENAME_$devnum
done

# now we have a list of dirs with dates and sizes. let's find out what we need to remove.
sort $TEMPFILE1 >$TEMPFILE2
:> $TEMPFILE1
secmax=$secnum
g_archive="YES"
devnum=1
eval devicename=\$DEVICENAME_$devnum
while [ "$g_archive" == "YES" -o ! -z "$devicename" ]; do
  secnum=0
  while [ ! -z "$devicename" ]; do
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "FREEING SPACE ON DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: ${freespace[$devnum]}MB"
    fi
    if [[ "${archive[$devnum]}" == "NO" && "$g_archive" == "YES" ]]; then
      let devnum=devnum+1
      eval devicename=\$DEVICENAME_$devnum
      continue
    elif [[ "${static_section[$devnum]}" == "NO" ]]; then
      let devnum=devnum+1
      eval devicename=\$DEVICENAME_$devnum
      continue
    fi
    for modname in ${dirs[$devnum]}; do
      if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
        if [[ "$TESTRUN" == "YES" ]]; then
          echo "DEVICE $devicename: ENOUGH FREESPACE ON THIS DEVICE (${freespace[$devnum]}MB)."
        fi
        break
      fi
      let secnum=secnum+1
      if [[ ${dsize[$secnum]} -ne 0 && ${dsize[$secnum]} -lt ${sectionsize[$secnum]} ]]; then
        if [[ "$TESTRUN" == "YES" ]]; then
          echo "SECTION $( echo $modname | cut -d ':' -f 1): $( expr ${sectionsize[$secnum]} / 1024)MB - maximum: $(expr ${dsize[$secnum]} / 1024)MB"
        fi
        while read -a readline; do
          if [[ $devnum -eq ${readline[4]} && $secnum -eq ${readline[3]} ]]; then
            freeupspace ${readline[2]} ${readline[1]} ${secnum:="NULL"} ${archdirname[$secnum]:="NULL"} ${archdevnum[$secnum]:=NULL}
            if [[ "$TESTRUN" == "YES" || ! -e ${readline[2]} ]]; then
              if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
                break
              fi
              if [[ ${dsize[$secnum]} -gt ${sectionsize[$secnum]} ]]; then
                if [[ "$TESTRUN" == "YES" ]]; then
                  echo "DEVICE $devicename: SECTION $modname: SECTIONSPACE ACHIEVED ($((${dsize[$secnum]}/1024))MB) - CONTINUING TO NEXT."
                fi
                break
              fi
            fi
          fi
        done < $TEMPFILE2
      fi
      archive[$devnum]="NO"
    done
    # free more space if avail space is not yet reached
    if [[ ${freespace[$devnum]} -lt ${setfree[$devnum]} ]]; then
      while read -a readline; do
        if [[ ${freespace[$devnum]} -lt ${setfree[$devnum]} && $devnum -eq ${readline[4]} ]]; then
          freeupspace ${readline[2]} ${readline[1]} "NULL" "NULL" "NULL"
          if [[ "$TESTRUN" == "YES" || ! -e ${readline[2]} ]]; then
            if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
              if [[ "$TESTRUN" == "YES" ]]; then
                echo "DEVICE $devicename: ENOUGH FREESPACE ON THIS DEVICE (${freespace[$devnum]}MB)."
              fi
              break
            fi
          fi
        fi
      done < $TEMPFILE2
    fi
    # end loop - continue to next device
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
  done
  if [[ "$g_archive" == "YES" ]]; then
    g_archive="NO"
    devnum=1
    eval devicename=\$DEVICENAME_$devnum
  fi
done

# Move previously marked dirs correctly
while read -a readmove; do
  if [[ ! -z "${readmove[0]}" ]]; then
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "MOVING ${readmove[0]} to $(date +$SITEDIR/${readmove[1]})"
    else
      mkdir -m0777 -p $(date +$SITEDIR/${readmove[1]})
      mv -fRp ${readmove[0]} $(date +$SITEDIR/${readmove[1]}/)
    fi
  fi
done < $TEMPFILE3
if [[ "$TESTRUN" == "YES" ]]; then
  echo -e "\n$(date "+%a %b %e %T %Y") PSXC-FREE v${version} completed."
else
  :> $TEMPFILE1
  :> $TEMPFILE2
  :> $TEMPFILE3
fi
exit 0

