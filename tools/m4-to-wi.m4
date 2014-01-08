divert(-1)dnl
changequote({,})

define({_kap}, {=== $1 ===})
define({_mailto}, {[[mailto:$1]]})
define({_uri}, {[[__fdir/$1|$2]]})
define({_url}, {[[$1|$2]]})
define({_par})
define({_uv}, {"$1"})
define({_li}, {* [[__fdir/patsubst($1, {\.html$})|$2]]})
define({_rel}, {$1})
define({_setyes})
define({_title}, {= $1 =})
define({_titleh}, {= $1 =})
define({_h})
define({_a}, {[[__fdir/$1|$2]]})
define({_bf}, {**$1**})
define({_i}, {''$1''})
define({_prevnext})
define({_m}, {\($1\)})
define({_background})
define({_br}, {

})

define({_fotky_tabor}, {fotky/tabor/$1})

dnl musi byt posledni na radku
divert(0)dnl
