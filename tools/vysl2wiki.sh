#!/bin/bash

VYSL2WIKI=/home/vitas/vs/tep/tools/vysl2wiki.pl
INDIR=/home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/
OUTDIR=/home/vitas/git/web/


function one() {
  FILE="$1"
  WILE="${FILE%.html}.wiki"
  echo "$VYSL2WIKI" "$INDIR/$FILE" '>' "$OUTDIR/$WILE"
  "$VYSL2WIKI" "$INDIR/$FILE" > "$OUTDIR/$WILE"
}


(
  cd "$INDIR"
  find -name 'vysl?.html'

) | while read FILE ; do
  one "$FILE"
done

