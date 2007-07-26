#!/bin/bash
# Packaging script, executed by ng-svn. Can be invoked manually.
# It creates a tar-ball, tagging it with revision-number, putting it in the
# right directory (files/type), and optionally tagging it with a tag.
# (Tags are e.g. version numbers or beta-numbers, like v1.0.3 or beta5)

## Configuration directives!
# Where we're supposed to put output stuff, it's $DIR/files/$TYPE
DIR="/home/www/scripts/template-mirror"
SVNPATH_stable="file:///svn/pzs-ng/project-zs-ng/branches/pzs-ng_v1/trunk/"
SVNPATH_testing="file:///svn/pzs-ng/project-zs-ng/branches/pzs-ng_v1/trunk/"
SVNPATH_unstable="file:///svn/pzs-ng/project-zs-ng/branches/pzs-ng_v1/trunk/"
SVNPATH_volatile="file:///svn/pzs-ng/project-zs-ng/trunk/"
## Configuration ends here!

REVISION="$1"
TYPE="`echo $2|tr A-Z a-z`"
TAG="`echo $3|tr A-Z a-z`"

if [ -z "$REVISION" ] || [ -z "$TYPE" ]; then
	echo "- Specify two arguments; revision number and type."
	echo "-  $0 <revision> <type> [tag]"
	exit 1
fi

if [ ! -d "files/$TYPE" ]; then
	echo "- Invalid type specified."
	exit 1
fi

echo "- Putting archive for upload as '$TYPE'."
DIR="$DIR/files/$TYPE"

SVNPATH="$(eval echo \$SVNPATH_$TYPE)"
if [ ! -z "$TAG" ]; then
  TARGETDIR="project-zs-ng_r$REVISION-$TAG/"
  TARGETARCHIVE="project-zs-ng_r${REVISION}-$TAG.tar.gz"
  EXPORTAPPEND=" as '$TAG'"
else
  TARGETDIR="project-zs-ng_r$REVISION/"
  TARGETARCHIVE="project-zs-ng_r${REVISION}.tar.gz"
  EXPORTAPPEND=""
fi


echo "- Generating archive."

echo -n " * Exporting r$REVISION$EXPORTAPPEND... "
svn export --quiet -r$REVISION "$SVNPATH" "$TARGETDIR" 2> /dev/null

if [ $? -gt 0 ]; then
  echo "error!"
  exit 0
fi
echo "done!"

echo -n " * Tagging ng-version.c with revision-number... "
echo -n '#include "ng-version.h"

const char* ng_version = "' > $TARGETDIR/zipscript/src/ng-version.c
if [ ! -z "$TAG" ]; then
	echo -n "$(echo $TAG|sed 's/"//g')-r$REVISION" >> $TARGETDIR/zipscript/src/ng-version.c
else
	echo -n "r$REVISION" >> $TARGETDIR/zipscript/src/ng-version.c
fi
echo '";' >> $TARGETDIR/zipscript/src/ng-version.c
echo "done!"

echo -n " * Wrapping in tar and gzip... "
tar czf "$DIR/$TARGETARCHIVE" "$TARGETDIR/"
echo "done!"

echo -n " * Wiping directory... "
rm -r "$TARGETDIR"
echo "done!"

echo "+ Done!"
