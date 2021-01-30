#!/bin/sh

#helper script to replace #xxx (with x) is a number by url to issue/pullrequest
#the tag [#xxx] can be anywhere (start, middle, end of line)

FILE=InstallerChangelog.md

[ -e $FILE ] && sed -i 's![^[]#\([0-9]\+\)! [#\1]\(https://github.com/AdoptOpenJDK/openjdk-installer/issues/\1)!g' $FILE

echo $?
