divert(-1)dnl
changequote({,})

define({_style_add})
define({_kap}, {=== $1 ===})
define({_mailto}, {[[mailto:$1]]})
define({_uri}, {[[__fdir/$1|$2]]})
define({_url}, {[[$1|$2]]})
define({_par})
define({_uv}, {&[&[uv _ex($@)&]&]})
define({_li}, {* [[__fdir/patsubst($1, {\.html$})|$2]]})
define({_rel}, {$1})
define({_setyes})
define({_title}, {= $1 =})
define({_titleh}, {= $1 =})
define({_h})
define({_a}, {ifelse(substr($1,0,4),http,[[$1|$2]],[[__fdir/$1|$2]])})
define({_bf}, {**$1**})
define({_i}, {''$1''})
define({_prevnext})
define({_m}, {$$1$})
define({_background})
define({_background})
define({_meter}, {\m})
define({_br}, {

})

dnl define({_tr_beg}, {ifdef({__intr},{)})define({__intr}, 1)_tr(})
dnl define({_td_beg}, {ifdef({__intd},{)})define({__intr}, 1)_tr(})

define({_expand},  {$*})

define({_table_html},  {
_subtr(_subend($*))
})

define({_table_html_math},  {
MATHTABLE
_subtr(_subend($*))
})

dnl define({_subtr}, {patsubst({$*}, {<\(TR\|tr\)[^>]*>},    {) _trb(}   )})
define({_subend},{patsubst({$*}, {</\(TR\|TD\|tr\|td\)>},{}          )})

define({_subtr}, {_my_split({$*}, <\(TR\|tr\)[^>]*>,    {_trb}, {_nic})})

dnl define({_tr_beg}, {TR})
dnl define({_td_beg}, {TD})

dnl define({_tr_end}, {undefine({__intr}))})
dnl define({_td_end}, {undefine({__intd}))})

define({_my_split}, dnl str, delim _funcion)
{$4(patsubst({$1}, {$2}, {)$3(}))})

define({_carky}, {{$@}})
define({_dt}, {**$1:**$2\\})
define({_td}, {<td>$@</td>})
define({_tr}, {<tr>$@</tr>})
define({_TR}, {<tr>$@</tr>})
define({_TD}, {<td>$@</td>})

define({_trb}, {|| _my_split({$*}, {<\(TD\|td\)[^>]*>}, {_tdb}, {_nic})
})
define({_nic}, {})

dnl define({_trb}, {)_tr(})
define({_nl}, {
})

define({_tdb}, {dnl
patsubst({patsubst({$*}, [_nl ][_nl ]*, { })}, { *$}, {}) || })

dnl define({_tdb}, {TD[$*]})

define({_fotky_tabor}, {fotky/tabor/$1})
define({_exp}, {$*})

dnl musi byt posledni na radku



dnl #######################################
dnl makra texmac.m4u8

dnl WARNING: automaticly generated, do NOT modify (changes will be lost) !!!


define({_leftline}, {<p align="left">$1</p>})


define({_exclaim},       \exclaim)       dnl {!})
define({_angle},         \angle)         dnl {&ang;})
define({_measuredangle}, \measuredangle) dnl {_angle()})
define({_langle},        \lagle)         dnl {&lang;})
define({_rangle},        \rangle)        dnl {&rang;})
define({_Delta},         \Delta)         dnl {&Delta;})
define({_deg},           \deg)           dnl {<sup>o</sup>})
define({_bullet},        \bullet)        dnl {&bull;})
define({_dagger}, {+})
define({_check}, {translit($1, 
  {acdeinorstuyzACDEINORSTUYZáčďéíňóřšťúýžÁČĎÉÍŇÓŘŠŤÚÝŽěůĚŮ},
  {áčďéíňóřšťúýžĂČĎÉÍŇÓŘŠŤÚÝŽacděinorstůyzACDĚINORSTŮYZeuEU})})
define({_check}, {ifelse(
	$1,a,ă,
	$1,c,č,
	$1,d,ď,
	$1,e,é,
	$1,i,í,
	$1,n,ň,
	$1,o,ó,
	$1,r,ř,
	$1,s,š,
	$1,t,ť,
	$1,u,ú,
	$1,y,ý,
	$1,z,ž,
	$1,A,Ă,
	$1,C,Č,
	$1,D,Ď,
	$1,E,É,
	$1,I,Í,
	$1,N,Ň,
	$1,O,Ó,
	$1,R,Ř,
	$1,S,Š,
	$1,T,Ť,
	$1,U,Ú,
	$1,Y,Ý,
	$1,Z,Ž,
	$1)})
define({_apostrof}, {ifelse(
	$1,a,á,
	$1,e,é,
	$1,i,í,
	$1,o,ó,
	$1,u,ú,
	$1,y,ý,
	$1)})

define({_agrave},               \arave)                 dnl {&agrave;})  
define({_tilde},                { })                    dnl {&^})
define({_hat},                  \hat)                   dnl  {^})
define({_parallel},             \parallel)              dnl {||})
define({_perp},                 \perp)                  dnl {&perp;})
define({_pm},                   \pm)                    dnl {&plusmn;})
define({_bar},                  \bar)                   dnl {|})
define({_mid},                  \mid)                   dnl {|})
define({_em},                   {''$1''})               dnl {<em>$1</em>})
define({_dot},                  .)                      dnl  {.})
define({_gt},                   \gt)                    dnl {&gt;})
define({_lt},                   \lt)                    dnl {&lt;})
define({_geq},                  \geq)                   dnl {&ge;})
define({_ge},                   \ge)                    dnl        {&ge;})
define({_leq},                  \leq)                   dnl  {&le;})
define({_le},                   \le)                    dnl {&le;})
define({_cap},                  \cap)                   dnl {&cap;})
define({_cup},                  \cup)                   dnl {&cup;})
define({_land},                 \land)                  dnl  {&and;})
define({_lor},                  \lor)                   dnl  {&or;})
define({_lnot},                 \lnot)                  dnl {&not;})
define({_lbrace},               \lbrace)                dnl {[})
define({_rbrace},               \rbrace)                dnl {]})
define({_vlna},                 { })                    dnl {~})
dnl  Box je pouze v rocnik01/zad1 tak to neva.
define({_Box},                  \Box)                   dnl {&otimes;})
define({_Diamond},              \Diamond)               dnl {&loz;})
define({_uparrow},              \uparrow)               dnl {^})
define({_Longrightarrow},       \Longrightarrow)        dnl {-----&gt;})
define({_rightarrow},           \rightarrow)             dnl {&rarr;})
define({_smallrightarrow},      \smallrightarrow)       dnl {&rarr;})
define({_checkmark},            \checkmark)             dnl {&radic;})
define({_mapsto},               \mapsto)                dnl  {|--&gt;})
define({_to},                   \to)                    dnl {-&gt;})
dnl \def\Rightarrow	{--&gt;}
define({_Rightarrow},           \Rightarrow)            dnl {&rArr;})
define({_leftarrow},            \leftarrow)             dnl {&larr;})
define({_leftrightarrow},       \leftrightarrow)        dnl {&harr;})
define({_primka},               \primka)                dnl {&harr;})
define({_poloprimka},           \poloprimka)            dnl {&rarr;})
define({_iff},                  \iff)                   dnl { &hArr; })
define({_Leftrightarrow},       \Leftrightarrow)        dnl {&hArr;})
define({_Leftarrow},            \Leftarrow)             dnl {&lt;--})
define({_longleftarrow},        \longleftarrow)         dnl {&lt;---})
define({_longrightarrow},       \longrightarrow)        dnl {---&gt;})
define({_longleftrightarrow},   \longleftrightarro)     dnl {&lt;---&gt;})
define({_vdots},                \vdots)           dnl {:})
define({_doteq},                \doteq)           dnl {&cong;})
define({_cong},                 \cong)            dnl {&cong;})
define({_sim},                  \sim)             dnl {&sim;})
define({_neq},                  \neq)             dnl {&ne;})
define({_leq},                  \leq)             dnl {&le;})
define({_equiv},                \equiv)           dnl {&equiv;})
define({_subset},               \subset)          dnl {&sub;})
define({_dag},                  \dag)             dnl {+})
define({_ddag},                 \ddag)             dnl  {++})
define({_spadesuit},            \spadesuit)                dnl  {&spades;})
define({_heartsuit},            \heartsuit)                dnl  {&hearts;})
define({_circ},                 \circ)             dnl  {o})
define({_ast},                  \ast)             dnl {*})
define({_vee},                  \vee)             dnl {&or;})
define({_wedge},                \wedge)           dnl {&and;})
define({_sum},                  \sum)             dnl {&sum;})
define({_hrule}, {<hr size="1">})
define({_hline}, {_NOALIGN(<hr size="1">)})

define({_crqq}, {&ldquo;})
define({_frqq}, {&raquo;})
define({_flqq}, {&laquo;})
define({_crq}, {&laquo;})
define({_clq}, {&raquo;})

define({_nomath}, {<i>$1</i>})
define({_sin},          \sin)           dnl {_nomath(sin)})
define({_cos},          \cos)           dnl {_nomath(cos)})
define({_tg},           \tg)           dnl {_nomath(tg)})
define({_arctg},        \arctg)         dnl {_nomath(arctg)})
define({_max},          \max)           dnl {\max{_nomath(max)})
define({_triangle},     \triangle)      dnl  {&Delta;})
define({_in},           \in)            dnl {&isin;})
define({_ni},           \ni)            dnl {&ni;})
define({_notin},        \notin)         dnl {&notin;})
define({_minus},        \minus)         dnl {})
define({_star},         \star)          dnl {*})
define({_infty},        \infty)         dnl {&infin;})

define({_par}, {
<p>})
define({_hbox}, {$1})
define({_vbox}, {$1})
define({_setbox}, {})
define({_comment}, {<!-- comment -->dnl})
define({_underline}, {<u>$1</u>})
define({_underbar}, {<u>$1</u>})
define({_centerline}, {<p aling="center">$1</p>})
define({_tilda}, {&nbsp;})
define({_tilda}, { })

dnl define({_uv}, {&bdquo;_ex($1)&ldquo;})
define({_rightline}, {<p align="right">$1</p>})
define({_noindent}, {})


define({_medskip}, {<p>})
define({_medbreak}, {<p>})
define({_smallskip}, {<p>})
define({_smallbreak}, {<p>})
define({_bigskip}, {<p>})
define({_bigbreak}, {<p>})
define({_vfill}, {<p>})
define({_eject}, {<p>})
define({_parskip}, {})
define({_odsazene}, {})

define({_obrazky}, {<img src="__fdir/patsubst($1,{|.*}).png" id="patsubst($1,{^.*|})">})
define({_obref}, {<a href="&%$1">$1</a>})

define({_epsfbox}, {<img src="__fdir/$1.png">})
define({_obrbox}, {<img src="__fdir/$1.png">})

define({_nobreak}, {})

dnl  carka bude vysedena
define({_comma}, {&;})
define({_semicolon}, { })
define({_dots}, ...)
define({_cdots}, {\cdots{}})
define({_ldots}, {\ldots{}})
define({_bbackslash}, \\) dnl {<br>})
define({_sup},          {^&[$1&]})
define({_sub},          {_&[$1&]})
define({_percent},      {\%}) 	dnl {%})
define({_over},         {\over{}}) 		dnl {/})
define({_sqrt},         {\sqrt&[$1&]})  dnl {&radic;($1)})
define({_sqrte},        {\sqrt&[&]}) 	dnl {&radic;})
define({_root},         {\root{}}) 		dnl {<sup>$1</sup>&radic;})
define({_of},           {\of{}}) 	        dnl {($1)})
define({_ge},           {\ge{}}) 		dnl {&phi;}){&ge;})
define({_alpha},        {\alpha{}}) 	dnl {&phi;}){&alpha;})
define({_beta},         {\beta{}}) 		dnl {&phi;}){&beta;})
define({_gamma},        {\gamma{}}) 	dnl {&phi;}){&gamma;})
define({_delta},        {\delta{}}) 	dnl {&phi;}){&delta;})
define({_epsilon},      {\epsilon{}}) 	dnl {&phi;}){&epsilon;})
define({_rho},          {\rho{}}) 		dnl {&phi;}){&rho;})
define({_varrho},       {\varrho{}}) 	dnl {&phi;}){&rho;})
define({_lambda},       {\lambda{}}) 	dnl {&phi;}){&lambda;})
define({_omega},        {\omega{}}) 	dnl {&phi;}){&omega;})
define({_pi},           {{\pi{}}{}}) 		dnl {&phi;}){&pi;})
define({_mu},           {\mu{}}) 		dnl {&phi;}){&mu;})
define({_theta},        {\theta{}}) 	dnl {&phi;}){&theta;})
define({_varphi},       {\varphi{}}) 	dnl {&phi;})
define({_phi},          {\phi{}}) 		dnl {&phi;})
define({_psi},          {\psi{}}) 		dnl {&psi;})
define({_minus},        {\minus{}}) 	dnl {-})
define({_left},         {\left&<}) 	dnl {$1})
define({_bigl},         {\bigl&<}) 	dnl {$1})
define({_right},        {\right&>}) 	dnl {$1})
define({_bigr},         {\bigr&>}) 	dnl {$1})
define({_s},            {s})             dnl { s})
define({_S},            {\S{}})             dnl { S })
define({_R},            {\R{}})             dnl {_htmlfont(b,R)})
define({_N},            {\N{}})             dnl {_htmlfont(b,N)})

define({_eq}, {=})
define({_ne}, \ne) dnl {&ne;})
dnl \def\def{}

define({_input}, {<!-- input $1 -->})
define({_endinput}, {<!-- endinput -->})


define({_quad}, {&nbsp;})
define({_qquad}, {&nbsp;})
define({_vrule}, {|})

define({_htmlfont}, {<$1>_ex($2)</$1>})
define({_it}, {_htmlfont(i,$1)})
define({_sc}, {_htmlfont(i,$1)})
define({_cal}, {_htmlfont(i,$1)})
define({_bf}, {_htmlfont(b,$1)})
define({_Bbb}, {_htmlfont(b,$1)})
define({_tt}, {_htmlfont(tt,$1)})
define({_sf}, {_htmlfont({font name=helvetica},$1)})
define({_rm}, {_ex($1)})
define({_elevenss}, {_htmlfont(b,$1)})

define({_cr}, {<BR>})
define({_crcr}, {<br>})
define({_break}, {<br>})

define({_relax}, {{}})

define({_at}, {@})
dnl %%%%%%%%%%%%%%%%%
dnl % zatim nedodelane, nebo quickhacky

define({_llap}, {$1})
define({_ignorespaces}, {})
define({_quatspace}, {})
define({_null}, {})
define({_mathop}, {$1})
define({_nopagenumbers}, {})
define({_line}, {<p>$1<br>})
define({_vphantom}, {$1})
define({_hangafter}, {})
define({_hangindent}, {})
define({_vadjust}, {$1})
define({_textfont}, {})
define({_looseness}, {})
define({_wd}, {})
define({_eqno}, {&nbsp;&nbsp;$1})
define({_eightpoint}, {})
define({_leaders}, {})
define({_copy}, {})

define({_choose}, { <i>nad</i> })
define({_let}, {<!-- let $1$2 -->})
define({_active}, {})
define({_gdef}, {})
define({_font}, {})
define({_kern}, {})
define({_bgroup}, {})
define({_baselineskip}, {})
define({_offinterlineskip}, {})
define({_hss}, {})
define({_strut}, {})
define({_egroup}, {})
define({_multicolumn}, {})
define({_hfil}, {})
define({_hfill}, {})
define({_hfilll}, {})
define({_midinsert}, {})
define({_endinsert}, {})
define({_textstyle}, {})
define({_displaystyle}, {})
define({_omit}, {})
define({_code48}, {&nbsp;})
define({_parbox}, {})
define({_catcode}, {})
define({_newcount}, {})
define({_mathcode}, {})
define({_underbrace}, {$1})
define({_overbrace}, {$1})
define({_discretionary}, {})

define({_vspace}, {<br>})
define({_hspace}, { })
define({_hskip}, { })
define({_vskip}, {<p>})
define({_fbox}, {})
define({_parindent}, {})
define({_tabskip}, { })
define({_hb}, {$2})
define({_smallskipamount}, {})


dnl %% _exx vyexpadnuje jak to jen jde
define({_exx}, {$1})
define({_ex}, {_exx(_exx(_exx(_exx(_exx(_exx(_exx($1)))))))})

define({_m}, {<code>_ex($1)</code>})
define({_m}, {$$1$})
define({_dm}, {<p align="center"><code>_ex($1)</code></p>})
define({_dm}, {
$$$1$$
})

define({_times}, {\times{}})
define({_cdot}, {\cdot{}})

define({_lfloor}, {|})
define({_rfloor}, {|})

define({_v}, {_check($1)})


define({_i}, {i})
define({_accent}, {ifelse($1$2,23,ů,$3)})

define({_items}, {pushdef({__enditems}, </ul>)<ul>})
define({_itemslet}, {pushdef({__enditems}, </ol>)<ol type=a>})
define({_itemsnum}, {pushdef({__enditems}, </ol>)<ol>})
define({_itemsnumskip}, {pushdef({__enditems}, </ol>)<ol>})
define({_itemsvarskip}, {pushdef({__enditems}, </ul>)<ul>})
define({_itemsletskip}, {pushdef({__enditems}, </ol>)<ol type=a>})
define({_enditems}, {__enditems(){}popdef(__enditems)})
define({_item}, {<li>})

dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dnl %% tabulka

define({_split}, {define({__split}, index({$1},{$2}))dnl
ifelse(__split,-1,{$1{,}},
  {substr({$1},0, __split){, }substr({$1}, eval(__split+len($2)))})})

define({_table_arg}, {define({__arg}, index({$1}, {
}))ifelse(__arg,-1,{,$1},{substr({$1}, 0, __arg){, }substr({$1},__arg)})})

define({_ttable}, {<table>define({__table_align}, $1)
_table_tr(_exx(_split($2,_cr)))
</table>})
define({_table_alig}, {crlccccccccccccccc})

define({_table_tr}, {ifelse({$1$2},,,{  <tr>_table_td(_exx(_split($1,$)),__table_align)</tr>
_table_tr(_exx(_split($2,_cr)))})})

define({_table_td}, {ifelse({$1$2},,,{_table_td_lo($1,substr($3,0,1))_table_td(_exx(_split($2,$)),
substr($3,1))})})
define({_table_td_lo}, {ifelse(index({$1},_NOALIGN),0,{_REAL$1)},{
  <td{} _talign($2)$1</td>})})

define({_talign}, {ifelse(
  $1, c, { align="center">},
  $1, r, { align="right" >},
  $1, l, { align="left"  >},
  $1, |, { align="center">|},
         {>})})

define({_table_cut_fst}, {substr($1,eval(index($1,_cr)+len(_cr)))})


define({_tr}, {TR[$1]})

define({_tr_lo}, {ifelse({$2},,,
  {define({__dr}, index({$2}, {$}))dnl
<td{}_align(substr({$1},0,1))substr({$2}, 0, __dr)</td>dnl
_tr_lo(substr({$1}, 1), substr(substr({$2}, __dr),1))})})


dnl  dirty hack:
dnl  v pripade ze se najde makro _NOALING predhodi se pred nej
dnl  _REAL a teprve to se vyexpanduje, pro jistotu se vyhodi vsechy
dnl  _NOALIGN, ktere zustali v pripadnem tele
dnl  
define({_noalign}, {_NOALIGN($1)})
define({_REAL_NOALIGN}, {<td colspan=20>
	patsubst($1,_NOALIGN, {_exx})</td></tr><tr>_table_td_lo(})




dnl %%%%

define({_cr}, {\cr})
define({_tabesc}, {patsubst({$1},{\$}, {&&})})

define({_halign}, {_ttable(llllllllllllllllllllllll,_table_cut_fst($1))})
define({_tabulka}, {_ttable(llllllllllllllllllllllll,_table_cut_fst($1))})
define({_matrix}, {_ttable(llllllllllllllllllllllll,$1)})
define({_cases}, {_ttable(llllllllllllllllllllllll,$1)})

define({_eqalignno}, {_ttable(rlllll,$1)})
define({_leqalignno}, {_ttable(rlllll,$1)})
define({_displaylines}, {_ttable(rlllll,$1)})

dnl define({_eqalign}, {_ttable(rlllll,$1)})
define({_eqalignno}, {\eqalignno&[_tabesc({$1})&]})
define({_eqalign}, {\eqalign&[_tabesc({$1})&]})
define({_matrix}, {\matrix&[_tabesc({$1})&]})
define({_displaylines}, {\displaylines&[_tabesc({$1})&]})
define({_cases}, {\cases&[_tabesc({$1})&]})
define({_matrix}, {\matrix&[_tabesc({$1})&]})

dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dnl %% latex

define({_frac}, {$1/$2})
define({_large}, {<h1>$1</h1>})
define({_Large}, {<h1>$1</h1>})

define({_begin}, {_begin_$1(})

dnl pozor tato definice dosti prohazi matchovani zavorek
dnl \def\table#1{<TABLE>_tr(_td(
dnl     patsubst(
dnl       patsubst(#1,
dnl         {\\\\\|\\cr}, {))
dnl         _tr(_td(}),
dnl         &, {)_td(} ) ))</TABLE> }

dnl \def\tr#1{<tr>#1</tr>}
dnl \def\td#1{ifelse(#1,{\hrule}, {<td colspan=10><hr></td>}, <td>#1</td>}

define({_begin_array}, {_begin_tabular($1)})
define({_begin_eqnarray}, {_begin_tabular($1)})

define({_end}, {ifelse($1,,,{)})})
define({_begin_center}, {_centerline($1)})
define({_begin_verbatim}, {<pre>$1$2</pre>})
define({_begin_enumerate}, {<ol>$1</ol>})
define({_begin_itemize}, {<ul>$1</ul>})
define({_begin_array}, {_ttable(_exx(_table_arg($1)))})
define({_begin_tabular}, {_ttable(_exx(_table_arg($1)))})
define({_begin_description}, {$1})

define({_cline}, {_noalign($1)})

dnl define({_gr}, {&[_ex($1)&]})
define({_gr}, {_ex($1)})
define({_copy}, {_ex($1)})
dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


dnl %% pikomat specific

define({_resenihl}, {_vr($1)})
define({_footnote}, {{}(_it(pozn. pod čarou: $2))})
define({_x}, {.})
define({_uu}, {})
define({_ku}, {})
define({_pozn}, {<p><b>Poznámka: </b>})
define({_f}, {f{}})
define({_Xof}, {Xof{}})
define({_res}, {_ur($1)})
define({_overline}, {$1})

define({_cm}, { cm})
define({_adresajedna}, {PIKOMAT, ODPM - Přírodovědné oddělení, Kremnická 32, 284 01})

define(_gr({}_sub({_})pict{}_sub({n})o){}_comma() _gr(1))

define({__pict_no}, {1})

define({_pict}, {
  <p align="center">
  <img alt="obrázek $1" src="__fdir/__base_jn().{}__pict_no().png"><p>
  define({__pict_no}, incr(__pict_no))})

define({_picts}, {_pict({$1 $2})})
define({_pictsss}, {_pict({$1 $2 $3})})
define({_pictssss}, {_pict({$1 $2 $3 $4})})

define({_put}, {})
define({_kom}, {<b>Komentář:</b>})
define({_oprav}, {<b>Opravovali:</b>})
define({_F}, {F{}})

dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dnl %% pikomat 15,16 specific


define({_ul}, {<p><h3>Úloha č. $1</h3>

})
define({_uloha}, {<p><h3>Úloha č. $1:</h3>

ifelse($2,,,{ _it($2)})

})

define({_ur}, {<p><h3>Úloha č. $1</h3>

})

define({_ulend}, {})
define({_ad}, {})


define({_zadaniserie}, {_ses($1)<p>_it(Termín odelslání: $2)<p>_it(Adresa:)$3<p>})
define({_se}, {_ses($1)})
define({_ses}, {
  _title(Zadání $1. série __rocnik_no(). ročníku)
    _h()
    _toc()})

define({_koment}, {<p><i>Komentář:</i>})
define({_reseni}, {<p><i>Řešení:</i>})
define({_opravovali}, {<p><i>Opravovali:</i>})

define({_vr}, {_title(Řešení $1. série __rocnik_no().ročníku)
_h()_toc() })

define({_tm}, {<p>_it(Termín odeslání: $1)<p>_it(Adresa:)
Pikomat, KPMS MFF UK, Sokolovská 83, 186 75 Praha 8
<p>})
define({_ps}, {Pikosobota č. $1 proběhne $2, začne v $3
  a skončí zhruba v $4})

define({_ps}, {
<p><b>Pikosobota</b> proběhne dne $2 od $3 do $4.
   Sraz je u východu stanice metra Nádraží Holešovice směrem k nádraží
   Praha-Holešovice (východ bez jezdících schodů).})

define({_pdf}, {
<p>Zadání je k dispozici také ve formátu <a href="$1">pdf</a>.</p>
<hr>
})

define({_pdfres}, {
<p>Řešení je k dispozici také ve formátu <a href="$1">pdf</a>.</p>
<hr>
})

define({_os}, { os})
define({_opzaos}, { op/os})
define({_op}, { op})
define({_ok}, { ok})
define({_om}, { om})
define({_ohm}, { ohm})
define({_okg}, { okg})
define({_ols}, { ols})
define({_omh}, { omh})
define({_omoh}, { om/oh})
define({_ol}, { ol})
define({_oh}, { oh})
define({_omin}, { omin})
define({_min}, { min})
define({_hod}, { h})
define({_dne}, { dne})
define({_og}, { og})
define({_cg}, { čg})
define({_oz}, { ož})
define({_uh}, {_measuredangle()})
define({_km}, { km})
define({_metr}, { m})
define({_decimetr}, { dm})
define({_mm}, { mm})
define({_ms}, { m/s})
define({_p}, { p})
define({_l}, { l})
define({_cms}, { cm/s})
define({_kmh}, { km/h})
define({_ksm}, { ks/min})
define({_ks}, { ks})
define({_kc}, { Kč})
define({_kg}, { kg})
define({_g}, { g})


define({_makeastdot}, {})

define({_code185}, {_check({(})s)})

dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dnl %% pikomat tabor 2001 specific
define({_nadp}, {_htmlfont(h2,$1)})
define({_zmerobraz}, {})
define({_obrazek}, {<img src="$2.png">})
define({_nobrazek}, {<img src="$1.png">})
define({_oblom}, {})
define({_noblom}, {})
define({_sirkao}, {})
define({_radku}, {})

dnl %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
dnl %% prechod na wiki

define({_toc}, {})
define({__rocnik_no}, {patsubst(__roc, ^0*)})
define({_toc_ulohy_v_indexu}, {* [[archiv/__rocnik_dir()zad1|__rocnik_dir()]]})
define({_arr_atput})
define({_setno})
define({_zadaniserie}, {_ses($1)
_it(Termín odelslání: $2)

_it(Adresa:)$3

})

define({_tm}, {
_it(Termín odeslání: $1)

_it(Adresa:) Pikomat, KPMS MFF UK, Sokolovská 83, 186 75 Praha 8

})


dnl seznam ucastniku
dnl _seznam(prezdivka, primeni, jmeno,datum narozeni,ulice,cp,mesto,psc,jpg)
dnl
define({_seznam}, {
<table><tr>
<td></td>
<td>přezdívka</td>
<td>jmeno</td>
<td>d.n.</td>
<td>adresa</td></tr>
_seznam_lo($@)
</table>})

dnl
dnl pomocne makro
dnl
define({_seznam_lo}, {ifelse({$1},,,{_seznam_one($1) _seznam_lo(shift($@))})})

dnl
dnl jeste pomocnejsi makro
dnl
define({_seznam_one},
{ <tr valign=top><td align=center>ifelse($9,,,<img src="img/$9.jpg">)</td>
      <td><b>$1</b></td><td>$2 $3</td><td>$4</td><td>  $5 $6 $7 $8</td></tr>
})



divert(0)dnl
