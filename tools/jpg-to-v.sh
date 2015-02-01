#!/bin/bash

echo   "this is obsolete: use tep/tools/do-n-m.jpg *.jpg"
exit

if [ -z "$1" ] ; then echo usage: $0 *.jpg ;  exit ; fi

function one () {
    OLDNAME="$1"
    NEWNAME=`echo "$OLDNAME" | sed "s/\.\([^.]\)*$/-v.jpg/"`
    echo "$OLDNAME > $NEWNAME" > /dev/stderr
    mv -i $OLDNAME $NEWNAME
}

for FILE in $* ; do
	one "$FILE" ;
done
