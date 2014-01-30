#!/bin/bash

function do_one () {
  SRC="$1"
  DST="$2"
  FDIR="$3"
  DDIR="`dirname "$DST"`"
  mkdir -p "$DDIR" || exit 0

  m4 -D "__fdir=$FDIR" "$PRG_DIR"/m4-to-wi.m4 "$SRC" |
  perl -pne '
     s#<hr>#----#i;
     s#~# #gi;
     s#</?p>##gi;
     s#<h(\d)>(.*)</h\d>#("="x$1) . $2 . ("="x$1)#gie;
     s#</?ul>##gi;
     s#</?ul>##gi;
     s#</?dl>##gi;
     s#<dt>([^\n<]*)#**$1**#gi;
     s#<dd>##gi;
     s#<a href="&%(.*)"[^>]*>([^<]*)</a>#[[\#$1|$2]]#g;
     s#<a href="(http[^"]*)"[^>]*>([^<]*)</a>#[[$1|$2]]#g;
     s#<a href="([^"]*)\.html"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#<a href="([^"]*)"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#<li>#* #gi;
     s#</li>##gi;
     s#<br[^>]*>#\\\\#gi;
     s#<p[^>]*>##gi;
     s#</?b>#**#gi;
     s#</?i>#'"''"'#gi;
     s#</?i>#'"''"'#ig;
     s#,,#!,,#ig;
     s#<img .*?src="?([^"]*)"?[^>]*>#[[Image($1)]]#gi;
     s#<(form|table)#{{{\!\n$&#gi;
     s#<(pre)>#{{{\n#gi;
     s#</(pre)>#\n}}}\n#gi;
     s#</(form|table)>#$&\n}}}#gi;
    ' >  "$DST"
  echo "$DST"
}

SRC_DIR="$1"
DST_DIR="$2"
SUBDIR="$3"
PRG_DIR="`dirname "$0"`"


( cd "$SRC_DIR"; find "$SUBDIR" -name '*.u8' ) | while read FILE ;  do
  FILE_WO_EXT=${FILE%.u8}
  FILE_DIR="`dirname "$FILE"`"
  do_one "$SRC_DIR/$FILE" "$DST_DIR/$FILE_WO_EXT.wiki" "$FILE_DIR"
done

