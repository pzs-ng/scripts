#!/bin/bash

cd "$1" || exit 1

if [ ! -f "ng-svn.pid" ]; then
	echo "ng-svn: no pidfile; starting."
	./ng-svn.pl > ng-svn.pl.log 2>&1
else
	pid=$(cat ng-svn.pid)
	lines=$(ps p $pid|wc -l)
	if [ $lines -lt 2 ]; then
		echo "ng-svn: invalid pid; starting."
		./ng-svn.pl > ng-svn.pl.log 2>&1
	fi
fi
