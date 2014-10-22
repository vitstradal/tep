#!/bin/sh

HPPDIR=/home/vitas/vs/hpp
M4_TO_WI_M4=/home/www/rails/tep/tools/m4-to-wi.m4

if [ -z "$1" ] ; then

        echo "usage: $0 zad1.tex [rocnik]"
        echo "          output: zad1.wiki"
        exit
fi

TEX="$1"
ROC="$2"
U8="${TEX%.tex}.u8"
WIKI="${TEX%.tex}.wiki"
BASE_JN=`basename $TEX| sed 's!\.\(u8\|il2\)$!!'`

if [ -z "$ROC" ] ; then
        REALPATH="`realpath $TEX`"
        echo "$REALPATH"
        ROC=`echo $REALPATH| sed -n 's/.*rocnik\([0-9][0-9]\).*/\1/p'|sed 's/^0*//'`
fi

if [ -z "$ROC" ] ; then

        echo "cannt determine ROC, specify as 2nd argument:"
        echo "usage: $0 zad1.tex ROC"
        exit
fi


FDIR="archiv/rocnik$ROC"
echo "archive dir: '$FDIR'"

perl -pne 's#\\m#\\meter#g' "$TEX" |
"$HPPDIR/ttm8"  -d "$HPPDIR/texmac.u8.ttm"  |
m4 -D "__fdir=$FDIR" -D "__roc=$ROC" -D "__base_jn=$BASE_JN" "$M4_TO_WI_M4" -  | tee /tmp/m4 |
  perl -pne "\$fdir=\"$FDIR/\";"'
   $mezera = 1;
   while(<>) {

     s#<hr>#----#i;
     s#^\s+=#=#;
     s#\&\^#~#gi;
     s#<!--(.*)-->#{{\# $1}}#gi;
     s#</?p>##gi;
     s#^<h(\d)>(.*)</h\d>#("="x$1) . $2 . ("="x$1)#gie;
     s#<h(\d)>(.*)</h\d>#**$2**#;
     s#\|\|\s*$#||\n#;
     s#</?ul>##gi;
     s#</?div[^>]*>##gi;
     s#</?ul>##gi;
     s#</?ol>##gi;
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
     s#<img .*?src="((fotky|archiv)[^">]*)".*id="([^"]*)".*?>#[[Image($1,id=$3)]]#gi;
     s#<img .*?src="(fotky[^">]*)".*?>#[[Image($1)]]#gi;
     s#<img .*?src="(archiv[^">]*)".*?>#[[Image($1)]]#gi;
     s#<img .*?src="([^">]*)".*?>#[[Image($fdir$1)]]#gi;
     s#^\s+(\[\[Image)#$1#i;
     s#<a href="&%([^">]*)"[^>]*>([^<]*)</a>#[[\#$1|$2]]#g;
     s#<a href="(http[^"]*)"[^>]*>([^<]*)</a>#[[$1|$2]]#g;
     s#<a href="([^"]*)\.html"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#<a href="([^"]*)"[^>]*>([^<]*)</a>#[['"$FDIR/"'$1|$2]]#g;
     s#\$\$(\[\[.*\]\])\$\$#$1#gi;
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

     if( /\$\$<table>/ ) {
       $tabmat++;
       s#^\$\$##;
     }
     s#(<td[^>]*>)(.*?)(</td>)#$1\$$2\$$3#g;
     if( /\$\$/ && $tabmat ) {
       $tabmat = 0;
       s#\$\$##;
     }

     s#^\s+([^\*].*)#$1#gi;
     s#^\s+(\*\*.*)#$1#gi;


     $mezera=0 if /\S/;
     $mezera++ if /^\s*$/;
     next if $mezera > 1;

     print;
   }' > "$WIKI"

echo "done: $TEX -> $WIKI"
