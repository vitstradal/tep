#!/bin/sh

if [ -z "$1" ] ; then
        cat <<EOL
usage $0 *.jpg
        z oobrazku obrazek-333.JPG vytvori:
        * obrazek-333-v.jpg (original)
        * obrazek-333-n.jpg (mensi)
        * obrazek-333-m.jpg (ikona)
        preskakuje  *-n.jpg, *-m.jpg, takze je mozne opravdu pouzit '*.jpg'
        i kdyz se pridaji nove obrazky
EOL
        exit
fi

GEO_N=840x840
GEO_M=300x300

for i in $*; do
        ii="${i%.JPG}"
        iii="${ii%.jpg}"
        iv="${iii%-v}"

        ni="${iv%-n}"
        mi="${iv%-m}"

        if [ "$iv" != "$ni" -o "$iv" != "$mi" ] ; then
                echo "skiping $i (is -n.jpg -m.jpg already)"
                continue
        fi

        if [ "${iv}-v.jpg" != "$i" ] ; then
                mv "$i" "${iv}-v.jpg" || exit
        fi

	echo -n "$i ... " ;
	convert "$iv-v.jpg" -auto-orient -geometry "$GEO_N" "$iv-n.jpg"
	echo -n "big done ... "
	#convert "$iv-n.jpg" -geometry "$GEO_M" "$iv-m.jpg"
	convert "$iv-v.jpg" -auto-orient -geometry "$GEO_M" "$iv-m.jpg"
	echo "small done"
done
