
quick:
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . setkani

all:
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . onas 
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . setkani
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . usage
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . provedouci
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . tabor
	rsync -r /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/img/ img/

want:
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . archiv
	bin/m4-to-wi.sh /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ . fotky


DIRS= \
        --exclude=fotky/      \
        --exclude=archiv/     \
        --exclude=php/        \
        --exclude=provedouci/ \
        --exclude=usage/      \
        --exclude=js/         \
        --exclude=prihlaska/  \
        --include='*/'        \
        --include='*.png'     \
        --exclude='*'         \

rsync:
	rsync -r -v $(DIRS) /home/zalohy/pikomat.ms.mff.cuni.cz/home/www/html/ .
