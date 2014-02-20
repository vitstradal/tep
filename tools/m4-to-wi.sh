#!/bin/bash

function do_one () {
  SRC="$1"
  DST="$2"
  FDIR="$3"
  DDIR="`dirname "$DST"`"
  mkdir -p "$DDIR" || exit 0

  echo $SRC
  perl -pne '
      s#<table[^>]*>#_table_html({#i;
      s#</table>#})#i;
      #s#<tr[^>]*>#_tr_beg()#i;
      #s#<th[^>]*>#_td_beg()#i;
      #s#<td[^>]*>#_td_beg()#i;
      #s#</tr>#_tr_end()#i;
      #s#</(th|td)>#_td_end()#i;
      ' "$SRC" |
  m4 -D "__fdir=$FDIR" "$PRG_DIR"/m4-to-wi.m4 -  |
  perl -pne "\$fdir=\"$FDIR/\";"'
     s#<hr>#----#i;
     s#~# #gi;
     s#<!--(.*)-->#{{\# $1}}#gi;
     s#</?p>##gi;
     s#^<h(\d)>(.*)</h\d>#("="x$1) . $2 . ("="x$1)#gie;
     s#<h(\d)>(.*)</h\d>#**$2**#;
     s#\|\|\s*$#||\n#;
     s#</?ul>##gi;
     s#</?div[^>]*>##gi;
     s#</?ul>##gi;
     s#</?dl>##gi;
     s#<code>([^<]*)</code>#`$1`#gi;
     s#&;#,#gi;
     s#&\[#{#gi;
     s#&<#(#gi;
     s#&>#)#gi;
     s#&&#&#gi;
     s#&\]#}#gi;
     s#[\r\n]+$# # if m{Opravovali};
     s#&nbsp;# #gi;
     s#<dt>([^\n<]*)#**$1**#gi;
     s#<dd>##gi;
     s#</?tt>#`#gi;
     s#<a href="(.*?)".*?>\s*<img .*?src="(fotky.*)".*?>\s*</a>#[[Image($2,link=$1)]]#gi;
     s#<a href="(.*?)".*?>\s*<img .*?src="(.*)".*?>\s*</a>#[[Image($fdir$2,link=$1)]]#gi;
     s#<img .*?src="(fotky[^">]*)".*?>#[[Image($1)]]#gi;
     s#<img .*?src="([^">]*)".*?>#[[Image($fdir$1)]]#gi;
     s#<a href="&%([^">]*)"[^>]*>([^<]*)</a>#[[\#$1|$2]]#g;
     s#<a href="(http[^"]*)"[^>]*>([^<]*)</a>#[[$1|$2]]#g;
     s#<a href="([^"]*)\.html"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#<a href="([^"]*)"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#<li>#* #gi;
     s#</li>##gi;
     s#<br[^>]*>#\\\\#gi;
     s#</?b>#**#gi;
     s#</?i>#'"''"'#gi;
     s#</?i>#'"''"'#ig;
     s#,,#!,,#ig;
#     s#<(form|table)#{{{\!\n$&#gi;
     s#<pre[^>]*>#{{{\n#gi;
     s#</(pre)>#\n}}}\n#gi;
#     s#</(form|table)>#$&\n}}}#gi;
     s#<p[^>]*>##gi;
     s#^\s(\S)#$1#gi;
    ' >  "$DST"
}

SRC_DIR="$1"
DST_DIR="$2"
SUBDIR="$3"
PRG_DIR="`dirname "$0"`"

if [ "$SUBDIR" == "-" ] ; then
        (cd "$SRC_DIR"; ls *.u8 ) | while read FILE ;  do
          FILE_WO_EXT=${FILE%.u8}
          do_one "$SRC_DIR/$FILE" "$DST_DIR/$FILE_WO_EXT.wiki" .
        done
        exit
fi


( cd "$SRC_DIR"; find "$SUBDIR" -name '*.u8' ) | while read FILE ;  do
  FILE_WO_EXT=${FILE%.u8}
  FILE_DIR="`dirname "$FILE"`"
  do_one "$SRC_DIR/$FILE" "$DST_DIR/$FILE_WO_EXT.wiki" "$FILE_DIR"
done

