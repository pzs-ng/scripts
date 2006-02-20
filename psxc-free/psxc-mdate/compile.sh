#!/bin/bash

glbin=/glftpd/bin

echo -e "\nThis will compile the psxc-mdate binary and"
echo "place it in a dir of yourchoice."
unset line
while [[ -z "$line" ]]; do
  echo -en "\nName of dir to copy to: ($glbin)> "
  read line
  if [[ -z "$line" ]]; then
    line=$glbin
  fi
  if [[ ! -d $line ]]; then
    unset line
  fi
done

echo -e "\ncompiling psxc-mdate to $line/psxc-mdate ...\n"
gcc -O2 -Wall -static -o $line/psxc-mdate psxc-mdate.c
if [[ $? == 0 ]]; then
  echo "Done."
else
  echo -e "\nFailed! Please find out why or contact psxc!"
fi

