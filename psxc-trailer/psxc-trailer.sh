#!/bin/bash

# psxc-trailer
##############
#
# Small script that fetches the qt trailer and image for movies.
# Takes one argument (path to releasedir). If no arg is given, it uses
# current path.
#
# Required bins are wget, sed, echo, tr, cut, tail, grep, bash

# debug option. do not remove the hash unless you know what you're doing
#set -x -v

# make sure we have access to all bins needed. Should not need to change this
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/glftpd/bin:$HOME/bin

# quality of trailer. Choose between
# 320 (lowest), 480, 640, 480p, 720p, 1080p (highest)
# More than one quality setting is allowed - first found will be used
# use "" to disable
trailerquality="480 480p 320"

# what name should be used on the trailer?
# use "" to keep name as is.
trailername="trailer.mov"

# download trailer image? ("yes"=yes, ""=no
downloadimage="yes"

# if yes, what name is to be used?
imagename=folder.jpg

# words to ignore - case does not matter
removewords="XViD SCREENER SCR DVDSCR DCDSCREENER DiVX H264 x264 REPACK TS TELESYNC TC TELECINE R5 DVDR DVDRip 720p 1080p BluRay BluRay PROPER LINE CAM HDTV LiMiTED"

# code below
[[ "$1" != "" && -d "$1" ]] && cd $1
releasename="$(echo "$PWD" | tr '/' '\n' | tail -n 1 | cut -d '-' -f 1 | tr 'A-Z' 'a-z')"
while [ 1 ]; do
  whilename=$releasename
  for word in $removewords; do
    word=$(echo $word | tr 'A-Z' 'a-z')
    rname="$(echo "$releasename" | sed -E "s/[\.|_]$word$//")"
    [[ "$releasename" != "$rname" ]] && {
      releasename=$rname
  echo "1 $whilename"
      break
    }
  done
  echo "2 $whilename"
  [[ "$releasename" == "$whilename" ]] && {
    break
  }
done
releasename="$(echo "$releasename" | sed -E "s/[\.|_][12][0-9][0-9][0-9]$//" | tr -d '\.')"
echo $releasename
output="$(wget -o /dev/null -O - "http://www.apple.com/trailers/home/scripts/quickfind.php?q=$releasename")"
outparse="$(echo $output | tr -d '\"' | tr ',' '\n')"
iserror=$(echo $outparse | grep -i "error:true")
[[ "$iserror" != "" ]] && {
  echo "An error occured. Unable to parse output"
  exit 1
}
poster="$(echo "$outparse" | grep -i "^poster:" | cut -d ':' -f 2- | tr -d '\\')"
location="http://www.apple.com$(echo "$outparse" | grep -i "^location:" | cut -d ':' -f 2- | tr -d '\\')"
echo "poster: $poster"
#echo "location: $location"

output2="$(wget --convert-links -o /dev/null -O - "$location")"
output2parse="$(echo $output2 | tr ' \?' '\n' | grep -i "^href=.*\.mov[\"]*$" | tr -d '\"' | cut -d '=' -f 2-)"
for quality in $trailerquality; do
  urllink=$(echo "$output2parse" | grep -i "${quality}.mov$" | head -n 1)
  [[ "$urllink" != "" ]] && {
    break
  }
done
[[ "$urllink" == "" ]] && {
  echo "Failed to fetch movielink"
  exit 0
}
echo $urllink

# download trailer and picture
[[ "$downloadimage" != "" && "$poster" != "" ]] && {
  echo "Downloading posterimage as $imagename"
  wget -o /dev/null -O $imagename $poster
}

[[ "$trailerquality" != "" && "$urllink" != "" ]] && {
  wget -o /dev/null -O the.fake $urllink
  fakelinkname=$(echo $urllink | tr '/' '\n' | grep -i "\.mov$")
  reallinkname=$(cat the.fake | tr -c 'a-zA-Z0-9\-\.\_' '\n' | grep -i "\.mov")
  reallink=$(echo $urllink | sed "s|$fakelinkname|$reallinkname|")
  rm -f the.fake
  [[ "$trailername" == "" ]] && {
    trailername=$(echo $urllink | tr '/' '\n' | grep -i "mov$" | tail -n 1)
  }
  echo "Downloading trailer in $quality quality as $trailername"
  wget -o /dev/null -O $trailername $reallink
}
echo "done"
exit 0
#echo "$output2parse"
