#!/bin/bash

find /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/fotky/ -name foto.dat | while read DAT ; do
  REL=${DAT#/home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/fotky/}
  DIR="${REL%foto.dat}"
  FILE="$DIR/fotky.wiki"
  if [ ! -d "web/$DIR" ] ; then
    FILE="${DIR%/}"
    FILE="fotky/`echo "$FILE"|sed 's!/!-!g'`.wiki"
  fi
  #echo "$FILE -  $DIR"
  /home/vitas/vs/tep/tools/foto2yaml.pl "$DAT" "/fotky/$DIR"  > "web/$FILE"
done
