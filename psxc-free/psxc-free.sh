#!/bin/bash
# This must be set correctly.
CONF=/glftpd/etc/psxc-free.conf

## code part below
####################################################################

logsimpledir()
{
  if [[ -d $1 ]]; then
    mdate=$($MDATE $1 $2)
    dsize=$(du -skxP $1 | awk '{print $1}')
    if [[ "${section_type[$secnum]}" == "FILES" ]]; then
      let calc_secfiles[$secnum]=${calc_secfiles[$secnum]}+1
    else
      let section_space[$secnum]=${section_space[$secnum]}+$dsize
    fi
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
    if [[ "${device_archive[$devnum]}" == "YES" && "${section_archive[$secnum]}" == "YES" ]]; then
      if [[ "${4}" != "NULL" ]]; then
        echo -e "$1\t$4\t$6" >>$TEMPFILE3
        if [[ "$TESTRUN" != "YES" ]]; then
          echo "$(date "+%a %b %e %T %Y") PSXCFREE_A: {$(echo /$1 | sed "s|$GLROOT||" | tr -s '/' | sed "s|/$||")} {$2}" >> $GLLOG
        else
          echo "DEVICE $devicename: MARKING $1 - FREEING $((${2}/1024))M"
        fi
        let freespace[$devnum]=${freespace[$devnum]}+${2}
        let freespace[${5}]=${freespace[${5}]}-${2}
        let section_space[$secnum]=${section_space[$secnum]}-${2}
        if [[ "$3" != "NULL" ]]; then
          let calc_secfiles[$secnum]=${calc_secfiles[$secnum]}-1
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
echo          rm -fR $delfile
        else
          echo "DEVICE $devicename: REMOVING $1 - FREEING $((${2}/1024))M ($((${freespace[$devnum]}/1024)))"
        fi
        echo -e "$1\t$4\t$6\talready_removed" >>$TEMPFILE3
        let freespace[$devnum]=${freespace[$devnum]}+${2}
        let section_space[$secnum]=${section_space[$secnum]}-${2}
        if [[ "$3" != "NULL" ]]; then
          let calc_secfiles[$secnum]=${calc_secfiles[$secnum]}-1
        fi
      fi
    fi
  else
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "DEVICE $devicename: IGNORING $1"
    fi
  fi
}

initialize_devvars()
{
  eval minfree[$devnum]=\$MINFREE_$devnum
  minfree[$devnum]=$((${minfree[$devnum]}*1024))
  eval setfree[$devnum]=\$SETFREE_$devnum
  setfree[$devnum]=$((${setfree[$devnum]}*1024))
  eval dirs[$devnum]=\$DIRS_$devnum
  eval daysback[$devnum]=\$DAYSBACK_$devnum
  excludes=$(echo "$EXCLUDES" | tr ' ' '|')
  device_archive[$devnum]=${device_archive[$devnum]:-"NO"}
  device_statsec[$devnum]=${device_statsec[$devnum]:-"NO"}
  for modname in ${dirs[$devnum]}; do
    if [[ ! -z "$(echo $modname | grep ':' | cut -d ":" -f 3)" ]]; then
      # section archiving on device
      device_archive[$devnum]="YES"
    fi
    if [[ ! -z "$(echo $modname | grep ':' | cut -d ":" -f 2)" ]]; then
      # sections on device
      device_section[$devnum]="YES"
    fi
  done
  freespace[$devnum]=$(df -Pk | grep ^$devicename | awk '{print $4}')
}

readconf()
{
  CONF1=$PWD/$0
  CONF2=$PWD/../etc/$0
  if [[ -r ${CONF1/.sh/.conf} ]]; then
    source ${CONF1/.sh/.conf}
  elif [[ -r ${CONF2/.sh/.conf} ]]; then
    source ${CONF2/.sh/.conf}
  else
    if [[ -r ${CONF} ]]; then
      source $CONF
    else
      echo "ERROR! Could not find/read psxc-free.conf! Edit the variable CONF in $0 to fix!"
      exit 1
    fi
  fi
}

readglconf()
{
  if [[ -z "$GLCONF" || ! -e $GLCONF ]]; then
    if [[ -e /etc/inetd.conf ]]; then
      glconf=$(grep $GLROOT /etc/inetd.conf | grep -- -r | grep -v ^# | tr '-' '\n' | grep "^r\ " | head -n 1 | awk '{print $2}')
    elif [[ -d /etc/xinetd.d ]]; then
      for xfile in /etc/xinetd.d/*; do
        glconf=$(grep $GLROOT $xfile | grep -- -r | grep -v ^# | tr '-' '\n' | grep "^r\ " | head -n 1 | awk '{print $2}')
        if [[ ! -z "$glconf" ]]; then
          break
        fi
      done
      if [[ -z "$glconf" ]]; then
        glconf=$(grep $GLROOT /etc/xinetd.conf | grep -- -r | grep -v ^# | tr '-' '\n' | grep "^r\ " | head -n 1 | awk '{print $2}')
      fi
    fi
    if [[ -z "$glconf" ]]; then
      if [[ -e /etc/glftpd.conf ]]; then
        glconf=/etc/glftpd.conf
      else
        echo "Your glftpd.conf file could not be found - please add \"GLCONF=/path/to/glftpd.conf\" in psxc-free.conf"
        exit 1
      fi
    fi
  else
    glconf=$GLCONF
  fi
  GLUPDATE=${GLUPDATE:-$GLROOT/bin/glupdate}
  OLDDIRCLEAN=${OLDDIRCLEAN:-$GLROOT/bin/olddirclean2}
  if [[ ! -x $GLUPDATE || ! -f $GLUPDATE ]]; then
    echo "The glupdate file could not be found/executed - please add \"GLUPDATE=/path/to/glupdate\" in psxc-free.conf"
    exit 1
  fi
  if [[ ! -x $OLDDIRCLEAN || ! -f $OLDDIRCLEAN ]]; then
    echo "The olddirclean2 file could not be found/executed - please add \"OLDDIRCLEAN=/path/to/olddirclean2\" in psxc-free.conf"
    exit 1
  fi
}

create_today()
{
  for modname in ${dirs[$devnum]}; do
    dirname=$SITEDIR/$(echo $modname | cut -d ":" -f 1)
    if [[ "$CREATEDATE" == "YES" ]]; then
      if [[ ! -z "$(echo "$dirname" | grep "%")" ]]; then
        if [[ ! -e $(date +$dirname) ]]; then
echo          mkdir -m0777 -p $(date +$dirname)
        fi
      fi
    fi
  done
}

calc_secsize()
{
  if [[ ! -z "$(echo $modname | grep ':' | cut -d ":" -f 2)" ]]; then
    ssize=$(echo $modname | cut -d ":" -f 2)
    dsize[$secnum]=$(echo $ssize | tr -cd '0-9')
    dfiles[$secnum]=0
    datelimit_sec[$secnum]=0
    case $ssize in
      *[gG]*)
        let dsize[$secnum]=${dsize[$secnum]}*1024
        section_type[$secnum]="SIZE"
        ;;
      *[tT]*)
        let dsize[$secnum]=${dsize[$secnum]}*1024*1024
        section_type[$secnum]="SIZE"
        ;;
      *[P\%]*)
        tsize=$(df -Pm | grep ^$devicename | awk '{print $2}')
        let dsize[$secnum]=tsize*${dsize[$secnum]}/100
        section_type[$secnum]="SIZE"
        ;;
      *[fF]*)
        dfiles[$secnum]=${dsize[$secnum]}
        dsize[$secnum]=0
        section_type[$secnum]="FILES"
        ;;
      *[dD]*)
        section_type[$secnum]="DAY"
        ;;
      *[wW]*)
        section_type[$secnum]="WEEK"
        ;;
      *[lL]*)
        section_type[$secnum]="MONTH"
        ;;
      *)
        section_type[$secnum]="SIZE"
        ;;
    esac
    if [[ "${section_type[$secnum]}" == "DAY" || "${section_type[$secnum]}" == "WEEK" || "${section_type[$secnum]}" == "MONTH" ]]; then
      if [[ "$USEGNUDATE" == "YES" ]]; then
        if [[ "${section_type[$secnum]}" == "DAY" ]]; then
          datelimit_sec[$secnum]=$(($(date +%s)-$(date --date="-${dsize[$secnum]} day + 1 day 0000" +%s)))
        elif [[ "${section_type[$secnum]}" == "WEEK" ]]; then
          datelimit_sec[$secnum]=$(($(date +%s)-$(date --date="-${dsize[$secnum]} week mon 0000" +%s)))
        else
          datelimit_sec[$secnum]=$(($(date +%s)-$(date --date="$(date +%Y-%m)-${dsize[$secnum]}" +%s)))
        fi
      else
        if [[ "${section_type[$secnum]}" == "DAY" ]]; then
          datelimit_sec[$secnum]=$(date -j -f "%a %b %d %T %Z %Y" "$(date -j -v-${dsize[$secnum]}d 0000)" "+%s")
        elif [[ "${section_type[$secnum]}" == "WEEK" ]]; then
          datelimit_sec[$secnum]=$(date -j -f "%a %b %d %T %Z %Y" "$(date -j -v-${dsize[$secnum]}w -v+1w -v-mon 0000)" "+%s")
        else
          datelimit_sec[$secnum]=$(date -j -f "%a %b %d %T %Z %Y" "$(date -j -v-${dsize[$secnum]}m -v+1m -v1d 0000)" "+%s")
        fi
      fi
      dsize[$secnum]=0
    elif [[ "${section_type[$secnum]}" == "SIZE" ]]; then
      let dsize[$secnum]=${dsize[$secnum]}*1024
    fi
    if [[ ! -z "$(echo $ssize | tr -cd 'MGTPFDWL')" ]]; then
      section_statsec[$secnum]="YES"
      device_statsec[$devnum]="YES"
    else
       section_statsec[$secnum]="NO"
    fi
  else
    datelimit_sec[$secnum]=0
    section_type[$secnum]="SIZE"
    dsize[$secnum]=0
    dfiles[$secnum]=0
    section_statsec[$secnum]="NO"
  fi
}

grab_archinfo()
{
  if [[ ! -z "$(echo $modname | grep ':' | cut -d ":" -f 3)" ]]; then
    archdirname[$secnum]=$(echo $modname | cut -d ":" -f 3)
    archdevnum[$secnum]=$(echo $modname | cut -d ":" -f 4)
    section_archive[$secnum]="YES"
    if [[ -z "${archdevnum[$secnum]}" ]]; then
      archdevnum[$secnum]=$devnum
    fi
    device_archive[${archdevnum[$secnum]}]="YES"
  else
   archdirname[$secnum]=""
   archdevnum[$secnum]=0
  fi
}

grab_dated()
{
  currdaysback=${daysback[$devnum]}
  datedir=0
  while [ $currdaysback -ge 0 ]; do
    if [ "$USEGNUDATE" != "YES" ]; then
      currdatedir=$(date -v-${currdaysback}d +${dirname[$secnum]})
    else
      currdatedir=$(date --date "-${currdaysback} day" +${dirname[$secnum]})
    fi
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
}

grab_normal()
{
  logdir "${dirname[$secnum]}"
}

freeupspace_dev()
{
  while read -a readline; do
    if [[ ${freespace[$devnum]} -le ${setfree[$devnum]} && $devnum -eq ${readline[4]} ]]; then
      freeupspace ${readline[2]} ${readline[1]} "NULL" "NULL" "NULL" ${readline[0]}
      if [[ "$TESTRUN" == "YES" || ! -e ${readline[2]} ]]; then
        if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
          if [[ "$TESTRUN" == "YES" ]]; then
            echo "DEVICE $devicename: ENOUGH FREESPACE ON THIS DEVICE ($((${freespace[$devnum]}/1024))MB)."
          fi
          break
        fi
      fi
    fi
  done < $TEMPFILE2
}

makefree()
{
  while read -a readline; do
    if [[ ${datelimit_sec[$secnum]} -gt 0 && ${datelimit_sec[$secnum]} -lt ${readline[0]} ]]; then
      break
    fi
    if [[ $devnum -eq ${readline[4]} && $secnum -eq ${readline[3]} && (${datelimit_sec[$secnum]} -ge ${readline[0]} || ${datelimit_sec[$secnum]} -eq 0) ]]; then
      if [[ "${section_statsec[$secnum]}" != "YES" && "${section_archive[$secnum]}" != "YES" ]]; then
        break
      fi
      if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
        if [[ "${section_type[$secnum]}" == "SIZE" && ${section_space[$secnum]} -ne 0 && ${section_space[$secnum]} -le ${dsize[$secnum]} && "${section_statsec[$secnum]}" == "YES" ]]; then
          if [[ "$TESTRUN" == "YES" ]]; then
            echo -e "DEVICE $devicename: SECTION $modname: SECTIONSPACE ACHIEVED ($((${section_space[$secnum]}/1024))MB) - CONTINUING TO NEXT.\n"
          fi
          break
        elif [[ "${section_type[$secnum]}" == "FILES" && ${calc_secfiles[$secnum]} -le ${dfiles[$secnum]} && "${section_statsec[$secnum]}" == "YES" ]]; then
          if [[ "$TESTRUN" == "YES" ]]; then
            echo "DEVICE $devicename: SECTION $modname: SECTIONSPACE ACHIEVED (${calc_secfiles[$secnum]}FILES) - CONTINUING TO NEXT."
          fi
          break
        elif [[ "${section_archive[$secnum]}" == "YES" ]]; then
          if [[ "$TESTRUN" == "YES" ]]; then
            echo -e "DEVICE $devicename: SECTION $modname: SECTIONSPACE ACHIEVED ($((${section_space[$secnum]}/1024))MB) - CONTINUING TO NEXT.\n"
          fi
          break
        fi
      fi
      freeupspace ${readline[2]} ${readline[1]} $secnum ${archdirname[$secnum]:="NULL"} ${archdevnum[$secnum]:=NULL} ${readline[0]}
    fi
  done < $TEMPFILE2
}

runfree()
{
  for modname in ${dirs[$devnum]}; do
    if [[ -z "$(echo $modname | grep ':' | cut -d ':' -f 2)" && -z "$(echo $modname | grep ':' | cut -d ':' -f 1 | tr -cd '%')" ]]; then
      continue
    fi
    let secnum=secnum+1
    if [[ "${section_statsec[$secnum]}" != "YES" && "${section_archive[$secnum]}" != "YES" ]]; then
      if [[ ${freespace[$devnum]} -gt ${setfree[$devnum]} ]]; then
        continue
      elif [[ "${section_type[$secnum]}" == "SIZE" && ${section_space[$secnum]} -le ${dsize[$secnum]} ]]; then
        continue
      elif [[ "${section_type[$secnum]}" == "FILES" && ${calc_secfiles[$secnum]} -le ${dfiles[$secnum]} ]]; then
        continue
      fi
    fi
echo ">>> $modname : $secnum : ${section_archive[$secnum]} : ${section_statsec[$secnum]}"
    makefree
    section_archive[$secnum]="NO"
#    section_statsec[$secnum]="NO"
  done
}

######## Main part ########

# VERSION
version=0.6

# Find and read psxc-free.conf
readconf

# Find location of glftpd.conf
readglconf

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

# Start reading section-info
while [ "$devicename" ]; do
  # filling vars
  initialize_devvars

  # testing to see if enough space is availible on device
  if [[ -z "${freespace[$devnum]}" ]]; then
    echo "FAILED! COULD NOT STAT $devicename!"
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
    continue
  fi

  if [[ "$TESTRUN" == "YES" ]]; then
    echo "MAPPING SECTIONS ON DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: $((${freespace[$devnum]}/1024))MB"
  fi

  # should we create today's date?
  create_today

  # initial check of device space
  if [[ "${device_archive[$devnum]}" != "YES" && "${device_statsec[$devnum]}" != "YES" ]]; then
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
    if [[ -z "$(echo $modname | grep ':' | cut -d ":" -f 2)" && -z "$(echo $modname | cut -d ':' -f 1 | tr -cd '%')" ]]; then
      continue
    fi
    let secnum=secnum+1
    section_space[$secnum]=0
    calc_secfiles[$secnum]=0
    dirname[$secnum]=$SITEDIR/$(echo $modname | cut -d ":" -f 1)

    # calc sectionsizes
    calc_secsize

    # grab archive info
    grab_archinfo

    if [[ ! -z "$(echo "${dirname[$secnum]}" | tr -cd "%")" ]]; then
      # dated dir structure.
      grab_dated
    else
      # normal dir structure.
      grab_normal
    fi
  done
  # end loop - continue to next device
  let devnum=devnum+1
  eval devicename=\$DEVICENAME_$devnum
done

# now we have a list of dirs with dates and sizes. let's find out what we need to remove.
sort $TEMPFILE1 >$TEMPFILE2

# first run in archive mode - find out what is to be moved, not removed
  echo
  secnum=0
  devnum=1
  eval devicename=\$DEVICENAME_$devnum
  while [ ! -z "$devicename" ]; do
    if [[ -z "${freespace[$devnum]}" || "${device_archive[$devnum]}" != "YES" || (${freespace[$devnum]} -gt ${setfree[$devnum]} && "${device_statsec[$devnum]}" != "YES" && "${device_archive[$devnum]}" != "YES") ]]; then
      let devnum=devnum+1
      eval devicename=\$DEVICENAME_$devnum
      continue
    fi
    if [[ "$TESTRUN" == "YES" ]]; then
      echo -e "DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: $((${freespace[$devnum]}/1024))MB - PASS ONE STARTING - MARKING/REMOVING DIRS"
    fi
    runfree
    device_archive[$devnum]="NO"
    device_statsec[$devnum]="NO"
    if [[ "$TESTRUN" == "YES" ]]; then
      echo -e "DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: $((${freespace[$devnum]}/1024))MB - PASS ONE DONE\n"
    fi
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
  done

# now, run it again in non-archive mode
  secnum=0
  devnum=1
  eval devicename=\$DEVICENAME_$devnum
  while [ ! -z "$devicename" ]; do
    if [[ -z "${freespace[$devnum]}" || (${freespace[$devnum]} -gt ${setfree[$devnum]} && "${device_statsec[$devnum]}" != "YES") ]]; then
      let devnum=devnum+1
      eval devicename=\$DEVICENAME_$devnum
      continue
    fi
    if [[ "$TESTRUN" == "YES" ]]; then
      echo -e "DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: $((${freespace[$devnum]}/1024))MB - PASS TWO STARTING - REMOVING DIRS"
    fi
    runfree
    # free more space if avail space is not yet reached

    if [[ ${freespace[$devnum]} -le ${setfree[$devnum]} ]]; then
      freeupspace_dev
    fi
    if [[ "$TESTRUN" == "YES" ]]; then
      echo -e "DEVICE #$devnum $devicename: (${dirs[$devnum]}) FREESPACE IS: $((${freespace[$devnum]}/1024))MB - PASS TWO DONE\n"
    fi
    let devnum=devnum+1
    eval devicename=\$DEVICENAME_$devnum
  done

# Move previously marked dirs correctly
if [[ "$TESTRUN" == "YES" ]]; then
  echo "MOVING DIRS PREVIOUSLY MARKED"
fi
while read -a readmove; do
  if [[ ! -z "${readmove[0]}" && -z "${readmove[3]}" ]]; then
    dateskew=$($MDATE ${readmove[0]} ${readmove[2]} dummyflag)
    if [ "$USEGNUDATE" != "YES" ]; then
      arcdatedir=$(date -v-${dateskew}S +${readmove[1]})
    else
      arcday=$((${readmove[2]}/86400))
      archour=$(((${readmove[2]}%86400)/3600))
      arcmin=$((((${readmove[2]}%86400)%3600)/60))
      arcsec=$((((${readmove[2]}%86400)%3600)%60))
      arcdatedir=$(date --date "-$arcday day -$archour hour -$arcmin min -$arcsec sec" +${readmove[1]})
    fi
    if [[ "$TESTRUN" == "YES" ]]; then
      echo "MOVING ${readmove[0]} to ${SITEDIR}/${arcdatedir}"
    else
      destdir=$(echo ${SITEDIR}/${arcdatedir} | tr -s '/')
echo      mkdir -m0777 -p $destdir
echo      mv -fRp ${readmove[0]} $destdir/
      $GLUPDATE -r $glconf $destdir/$(basename ${readmove[0]})
    fi
  fi
done < $TEMPFILE3
if [[ "$TESTRUN" == "YES" ]]; then
  echo -e "\n$(date "+%a %b %e %T %Y") PSXC-FREE v${version} completed."
else
  $OLDDIRCLEAN -r $glconf >/dev/null 2>&1
  :> $TEMPFILE1
  :> $TEMPFILE2
  :> $TEMPFILE3
fi
exit 0
