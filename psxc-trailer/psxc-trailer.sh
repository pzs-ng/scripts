#!/bin/bash

# psxc-trailer
##############
#
# Small script that fetches the qt trailer and image for movies.
# Takes one argument (path to releasedir). If no arg is given, it uses
# current path.
#
# Required bins are wget, sed, echo, tr, cut, tail, grep, bash, wc

# debug option. do not remove the hash unless you know what you're doing
#set -x -v

# make sure we have access to all bins needed. Should not need to change this
PATH=$PATH:/bin:/usr/bin:/usr/local/bin:/sbin:/usr/sbin:/usr/local/sbin:/glftpd/bin:$HOME/bin

# quality of trailer. Choose between
# 320 (smallest), 480, 640, 480p, 720p, 1080p (highest)
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
removewords="XViD SCREENER SCR DVDSCR DCDSCREENER DiVX H264 x264 REPACK TS TELESYNC TC TELECINE R5 DVDR DVDRiP 720p 1080p BluRay BluRay PROPER LINE CAM HDTV LiMiTED UNRATED READNFO BRRiP AC3 DTS"

# you can define how accurate you wish the search to be. lower the number
# if you need more results, or increase if you get a lot of false positives
accuracy=2

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
      break
    }
  done
  [[ "$releasename" == "$whilename" ]] && {
    break
  }
done

orgrelname=$releasename
countdot=$(echo $releasename | tr -cd '\.' | wc -c)
let countdot=countdot-0

while [ 1 ]; do
  releasename="$(echo "$releasename" | sed -E "s/[\.|_][12][0-9][0-9][0-9]$//" | tr -d '\.')"
  output="$(wget --ignore-length --timeout=10 -o /dev/null -O - "http://www.apple.com/trailers/home/scripts/quickfind.php?q=$releasename")"
  outparse="$(echo $output | tr -d '\"' | tr ',' '\n')"
  iserror=$(echo $outparse | grep -i "error:true")
  isresult=$(echo $outparse | grep -i "results:\[\]")
  [[ "$iserror" != "" ]] && {
    echo "An error occured. Unable to parse output"
    exit 1
  }
  [[ "$isresult" == "" ]] && {
    break
  }
  [[ $countdot -le $accuracy ]] && {
    break
  }
  releasename=$(echo $orgrelname | cut -d '.' -f 1-$countdot)
  let countdot=countdot-1
done
poster="$(echo "$outparse" | grep -i "^poster:" | cut -d ':' -f 2- | tr -d '\\')"
location="http://www.apple.com$(echo "$outparse" | grep -i "^location:" | cut -d ':' -f 2- | tr -d '\\')"

output2="$(wget --ignore-length --timeout=10 -o /dev/null -O - $location)"
output2parse="$(echo $output2 | tr ' \?' '\n' | grep -E -i "^href=.*\.mov[\"]*$|^href=.*small[_]?.*\.html[\"]*|^href=.*medium[_]?.*\.html[\"]*|^href=.*large[_]?.*\.html[\"]*|^href=.*low[_]?.*\.html[\"]*|^href=.*high[_]?.*\.html[\"]?.*" | tr -d '\"' | cut -d '=' -f 2-)"
for quality in $trailerquality; do
  urllink=$(echo "$output2parse" | grep -i "${quality}.mov$" | head -n 1)
  [[ "$urllink" != "" ]] && {
    break
  }
  sublink=""
  [[ "$quality" == "320" && "$(echo "$output2parse" | grep -E -i "small[_]?.*.html|low[_]?.*.html")" != "" ]] && {
    sublink=${location}$(echo "$output2parse" | grep -E -i "small.html[_]?.*|low[_]?.*.html" | tr '\>\<\ ' '\n' | head -n 1)
  }
  [[ "$quality" == "480" && "$(echo "$output2parse" | grep -E -i "medium[_]?.*.html")" != "" ]] && {
    sublink=${location}$(echo "$output2parse" | grep -E -i "medium[_]?.*.html" | tr '\>\<\ ' '\n' | head -n 1)
  }
  [[ "$quality" == "640" && "$(echo "$output2parse" | grep -E -i "large[_]?.*.html|high[_]?.*.html")" != "" ]] && {
    sublink=${location}$(echo "$output2parse" | grep -E -i "large[_]?.*.html|high[_]?.*.html" | tr '\>\<\ ' '\n' | head -n 1)
  }
  [[ "$sublink" != "" ]] && {
    output3="$(wget --ignore-length --timeout=10 -o /dev/null -O - $sublink)"
    output3parse="$(echo $output3 | tr -c 'a-zA-Z/:\._0-9\-' '\n' | grep -E -i "\.mov$")"
    urllink=$(echo "$output3parse" | grep -i "\.mov$" | head -n 1)
  }
  [[ "$urllink" != "" ]] && {
    break
  }
done
[[ "$urllink" == "" ]] && {
  echo "Failed to fetch movielink"
  exit 0
}

# download trailer and picture
[[ "$downloadimage" != "" && "$poster" != "" ]] && {
  echo "Downloading posterimage as $imagename"
  wget --ignore-length --timeout=10 -o /dev/null -O $imagename $poster
}

[[ "$trailerquality" != "" && "$urllink" != "" ]] && {
  wget --ignore-length --timeout=10 -o /dev/null -O the.fake $urllink
  fakelinkname=$(echo $urllink | tr '/' '\n' | grep -i "\.mov$")
  reallinkname=$(cat the.fake | tr -c 'a-zA-Z0-9\-\.\_' '\n' | grep -i "\.mov")
  reallink=$(echo $urllink | sed "s|$fakelinkname|$reallinkname|")
  rm -f the.fake
  [[ "$trailername" == "" ]] && {
    trailername=$(echo $urllink | tr '/' '\n' | grep -i "mov$" | tail -n 1)
  }
  echo "Downloading trailer in $quality quality as $trailername"
  wget --ignore-length --timeout=10 -o /dev/null -O $trailername $reallink
}
echo "done"
exit 0

