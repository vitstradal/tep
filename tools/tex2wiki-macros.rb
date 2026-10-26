# Makra pro tools/tex2wiki.rb.
#
#   macro :jmeno, ARITY, 'wiki se %1 %2'   text; argumenty se převedou
#   macro(:jmeno, ARITY) { |c, a1, …| … }    složitější; c.conv(a) převede argument
#   math  :jmeno, 'TeX pro MathJax'         uvnitř $…$ (\m -> \,{\rm m})
#   ignore :jmeno, …                        zahodit
#   ignore_dimen :hskip                     zahodit i s rozměrem (\hskip 1cm plus 1fil)
Tex2Wiki.macros do
  # --- struktura letáku ---------------------------------------------------
  macro(:ses, 2) { |c, n, termin| c.meta.update(kind: :zad, serie: n.to_i, termin: c.conv(termin).strip); '' }
  macro(:sesj, 2) { |c, n, termin| c.meta.update(kind: :zad, serie: n.to_i, termin: c.conv(termin).strip); '' }
  macro(:vr, 1) { |c, n| c.meta.update(kind: :vz, serie: n.to_i); '' }
  macro(:pruv, 2) { |c, n, nazev| c.meta.update(kind: :pruv, serie: n.to_i, nazev: c.conv(nazev).strip); "= #{c.conv(nazev).strip} =\n\n" }
  macro(:ul, 1) { |c, n| c.meta[:ul] = n.to_i; Tex2Wiki::Converter.line("=== Úloha č. #{n} === #ul#{n}\n\n") }
  macro(:ur, 1) { |_c, n| Tex2Wiki::Converter.line("=== Úloha č. #{n} === #ul#{n}\n\n") }
  macro(:ulend, 0) { |c| c.ulend }
  macro :reseni, 0, "\n\n''Řešení:''\n"
  macro(:koment, 0) { |c| c.junior ? "\n\n''Komentář pro řešitele:''\n" : "\n\n''Komentář:''\n" }
  macro :komentrodice, 0, "\n\n''Komentář pro rodiče/učitele:''\n"
  macro :opravovali, 1, "\n\nÚlohy %1 série opravovali a komentáře sepsali: "
  macro :pozn, 0, "\n\n**Poznámka:** "
  macro :definice, 0, "\n\n**Definice:** "
  macro :tvrzeni, 0, "\n\n**Tvrzení:** "
  macro :priklad, 0, "\n\n''Příklad:'' "
  macro :uloha, 0, "\n\n**Úloha:** "
  macro :dukaz, 0, "\n\n''Důkaz:'' "
  macro :veta, 1, "\n\n**%1** "
  macro(:nadpis, 0) { |c| Tex2Wiki::Converter.line("=== #{c.conv(c.read_arg_or_par).strip} ===\n\n") }
  macro(:podnadpis, 0) { |c| Tex2Wiki::Converter.line("==== #{c.conv(c.read_arg_or_par).strip} ====\n\n") }
  macro(:nadpisek, 0) { |c| "\n\n''#{c.conv(c.read_arg_or_par).strip}''\n\n" }
  macro :denik, 1, "\n\n''%1''\n\n"
  macro :pojem, 1, '%1'
  macro :mili, 0, "\n\n**Milé řešitelky, milí řešitelé,**\n\n"
  ignore :titulek, :dfend, :endinput_marker

  # --- obrázky -------------------------------------------------------------
  macro(:obrazky, 1) { |c, spec| c.obrazky(spec) }
  macro(:nadobrazky, 1) { |c, spec| c.obrazky(spec) }
  macro(:obref, 1) { |c, label| c.obref(label.strip) }
  macro(:XeTeXpdffile, 0) { |c| c.image(c.read_filename) }
  macro(:XeTeXpicfile, 0) { |c| c.image(c.read_filename) }
  macro(:includegraphics, 0) { |c| c.includegraphics }
  macro(:caption, 1) { |c, a| (t = c.conv(a).strip).empty? ? '' : "**#{t}**\n\n" }
  macro :label, 1, ''
  macro(:begin, 1) { |c, env| c.env_begin(env.strip) }
  macro(:end, 1) { |c, env| c.env_end(env.strip) }

  # --- seznamy -------------------------------------------------------------
  macro(:items, 1) { |c, _| c.list_begin('*') }
  macro(:itemsskip, 1) { |c, _| c.list_begin('*') }
  macro(:itemsvar, 1) { |c, _| c.list_begin(:var) }
  macro(:itemsvarskip, 1) { |c, _| c.list_begin(:var) }
  macro(:itemsnum, 1) { |c, _| c.list_begin('1.') }
  macro(:itemsnumskip, 1) { |c, _| c.list_begin('1.') }
  macro(:itemslet, 1) { |c, _| c.list_begin('a.') }
  macro(:itemsletskip, 1) { |c, _| c.list_begin('a.') }
  macro(:item, 0) { |c| c.list_item(c.in_var_list? ? c.read_arg : nil) }
  macro(:enditems, 0) { |c| c.list_end }
  macro(:listitem, 1) { |c, a| c.list_item_free(a) }
  ignore :listlvlup, :listlvldown, :endlist, :odsazene

  # --- písmo a odstavce ----------------------------------------------------
  macro :textbf, 1, '**%1**'
  macro :textit, 1, "''%1''"
  macro :emph, 1, "''%1''"
  macro :uv, 1, '„%1“'
  macro :underline, 1, '__%1__'
  macro :centerline, 1, "\n\n%1\n\n"
  macro :leftline, 1, "\n\n%1\n\n"
  macro :rightline, 1, "\n\n%1\n\n"
  macro :line, 1, '%1'
  macro :hbox, 1, '%1'
  macro :vbox, 1, '%1'
  macro :vtop, 1, '%1'
  macro :vcenter, 1, '%1'
  macro :mbox, 1, '%1'
  macro :text, 1, '%1'
  macro(:footnote, 0) { |c| c.footnote }
  macro :TODO, 1, ''
  macro :show, 1, ''
  macro :par, 0, "\n\n"
  macro :break, 0, "\\\\\n"
  macro(:tecky, 0) { |c| c.skip_brace_arg; ' …… ' }
  macro(:vyplntecky, 0) { ' …… ' }
  macro(:teckovana, 0) { "\n\n…………………………………………\n\n" }
  macro(:tabulka, 1) { |c, a| c.halign(a) }
  macro(:halign, 0) { |c| c.halign(c.read_arg) }
  macro(:endinput, 0) { |c| c.stop! }
  macro(:bye, 0) { |c| c.stop! }
  macro(:input, 0) { |c| c.read_filename; '' }
  text_char 'dots' => '…', 'ldots' => '…', 'quad' => ' ', 'qquad' => ' ', 'kulka' => '•',
            'S' => '§', 'clqq' => '„', 'crqq' => '“', 'TeX' => 'TeX', 'space' => ' ', 'rocnik' => ''
  ignore %w[bigskip medskip smallskip medbreak bigbreak smallbreak goodbreak filbreak
            vfill vfil hfill hfil hss vss eject supereject newpage noindent neodsad indent
            nobreak allowbreak strut relax ignorespaces leavevmode null centering
            bf it rm sf sl tt em Large large small begingroup endgroup bgroup egroup
            offinterlineskip nointerlineskip midinsert endinsert topinsert
            makeheadline nopagenumbers ninepoint tensf tensfnolig twelvesfm sixteensfm
            fourteensfm fourteensf tensfm tensfr tensfnoligr tentt teni hrulefill dotfill
            crcr cr hline linewidth textwidth hthickline cara myvrule noalign]
  ignore_dimen %w[hskip vskip kern mkern raise lower moveleft moveright leftskip rightskip
                  parindent parskip baselineskip topskip hsize vsize hoffset voffset tabskip]
  ignore_number %w[penalty looseness tolerance hfuzz]

  # --- matematika ----------------------------------------------------------
  { 'm' => 'm', 'cm' => 'cm', 'mm' => 'mm', 'dm' => 'dm', 'km' => 'km', 'kmh' => 'km/h',
    'l' => 'l', 'ml' => 'ml', 'kg' => 'kg', 'g' => 'g', 's' => 's', 'h' => 'h',
    'kc' => 'Kč', 'mil' => 'mil' }.each do |n, unit|
    math n, "\\,{\\rm #{unit}}"
    macro n, 0, " #{unit}"
  end
  math 'deg', '^\circ'
  math 'degree', '^\circ'
  math('tecky', ->(c) { c.skip_brace_arg; '\ldots\ldots' })
  math 'vyplntecky', '\ldots\ldots'
  math 'nmod', '\pmod{%1}', 1
  math 'N', '\mathbb{N}'
  math 'Z', '\mathbb{Z}'
  math 'male', '\scriptstyle'
  math 'fw', '{%1}', 1
  math 'podsebou', '\begin{matrix}%1\end{matrix}', 1
  math 'Tpodsebou', '\begin{matrix}%1\end{matrix}', 1
  math 'myvrule', '\vert'
  math 'sevenrm', ''
end
