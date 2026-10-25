# tex2wiki sync: najde TeXy zadání a vzoráků, převede je a zapíše do web repa.
#
# Co se smí zveřejnit, říká archiv/index.wiki ({{archiv 41|zrv|zr|z}}):
# z = zadání, r = vzorové řešení. Ručně upravené stránky se nepřepisují.
require 'digest'
require 'fileutils'
require 'open3'

module Tex2Wiki
  Source = Struct.new(:path, :rocnik, :junior, :kind, :serie, :rank, keyword_init: true) do
    def page
      "#{kind == :vz ? 'vz' : 'zad'}#{serie}"
    end

    def key
      [rocnik, junior, page]
    end
  end

  class Sync
    REDIRECT_STUB = /\A\s*(\{\{#.*?\}\}\s*)*\{\{redirect [^}]*\}\}\s*\z/m
    MARKER = /\A\{\{# tex2wiki: (?<src>\S+) out=(?<out>\h+) \}\}\n/

    attr_reader :log

    def initialize(web:, srcs:, write: false, force: false, redo_images: false, out: $stdout)
      @web = web
      @srcs = srcs
      @write = write
      @force = force
      @redo_images = redo_images
      @out = out
    end

    def say(msg)
      @out.puts msg
    end

    # --- zdroje --------------------------------------------------------------

    # soubory, které letak.tex projektu opravdu načítá (\input bez %)
    def inputs(project_dir)
      @inputs ||= {}
      @inputs[project_dir] ||= Dir.glob(File.join(project_dir, '*.tex')).select { |f| File.file?(f) && File.readable?(f) }.flat_map do |f|
        File.read(f, encoding: 'UTF-8').scrub.lines.grep_v(/\A\s*%/).flat_map { |l| l.sub(/(?<!\\)%.*/, '').scan(/\\input\s+"?([^\s"}]+)/).flatten }
      end.map { |n| n.sub(/\.tex\z/, '') }
    end

    def sources(rocnik)
      found = []
      @srcs.each_with_index do |dir, si|
        Dir.glob(File.join(dir, "#{rocnik}{_,/}**/*.tex")).each do |f|
          next unless File.basename(f) =~ /\A(zad|vz)\s?\d+j?\.tex\z/ && File.file?(f) && File.readable?(f)
          tex = File.read(f, encoding: 'UTF-8').scrub
          c = Converter.new(rocnik: rocnik)
          c.convert(tex)
          next unless c.meta[:serie] && %i[zad vz].include?(c.meta[:kind])
          next if c.meta[:kind] == :zad && !termin_fits?(c.meta[:termin], rocnik, c.meta[:serie])
          rel = f.delete_prefix("#{dir}/")
          junior = rel =~ %r{\A\d+_[^/]*j\b|/(s|r|l|zad|vz)\d+j/|j\.tex\z|junior}i ? true : false
          used = inputs(File.dirname(f)).include?(File.basename(f, '.tex')) ? 0 : 1
          found << Source.new(path: f, rocnik: rocnik, junior: junior, kind: c.meta[:kind],
                              serie: c.meta[:serie],
                              rank: [used, used.zero? ? -rel[/\A\d+_(\d+)/, 1].to_i : 0, -tex.size, si,
                                     File.basename(f)[/\d+/].to_i == c.meta[:serie] ? 0 : 1])
        end
      end
      # stejná stránka z více míst: prázdné šablony prohrají, pak pořadí --src (preklep-mirror
      # bývá opravenější), pak jméno sedí se sérií (zad5j.tex pro \ses5), pak načítaný
      # letákem (pozdější leták), pak delší
      found.group_by(&:key).map do |_, list|
        best = list.min_by { |x| [-x.rank[2] < TEMPLATE_SIZE ? 1 : 0, x.rank[3], x.rank.last, *x.rank] }
        (list - [best]).each { |o| say "  (#{o.path} přeskočen, přednost má #{best.path})" }
        best
      end.sort_by { |s| [s.junior ? 1 : 0, s.serie, s.kind == :vz ? 1 : 0] }
    end

    # ročník R začíná na podzim roku 1984 + R (1. a 2. série mají termín ještě ten rok);
    # leták 7 už nese zadání 1. série příštího ročníku
    def termin_fits?(termin, rocnik, serie)
      year = termin.to_s[/\b(19|20)\d\d\b/] or return true
      (serie <= 2 ? [1984 + rocnik] : [1984 + rocnik, 1985 + rocnik]).include?(year.to_i)
    end

    # --- zveřejnění ----------------------------------------------------------

    def index_path
      File.join(@web, 'archiv', 'index.wiki')
    end

    # {serie => "zrv"} z {{archiv 41|…}} / {{archiv_junior 41|…}}
    def flags(rocnik, junior)
      macro = junior ? 'archiv_junior' : 'archiv'
      line = File.read(index_path)[/\{\{#{macro}\s+#{rocnik}\|([^}]*)\}\}/, 1]
      return {} unless line
      line.split('|').each_with_index.to_h { |f, i| [i + 1, f.strip] }
    end

    def allowed?(src)
      f = flags(src.rocnik, src.junior)[src.serie].to_s
      src.kind == :vz ? f.include?('r') : f.include?('z')
    end

    # --- stránky ---------------------------------------------------------------

    def dir(rocnik, junior)
      File.join(@web, 'archiv', "rocnik#{rocnik}#{junior ? '/junior' : ''}")
    end

    def url(rocnik, junior, page)
      "/archiv/rocnik#{rocnik}#{junior ? '/junior' : ''}/#{page}"
    end

    def pdf_link(rocnik, junior, name)
      File.exist?(File.join(dir(rocnik, junior), name)) ? "#{url(rocnik, junior, name)}" : nil
    end

    def header(src, conv)
      r, j, n = src.rocnik, src.junior, src.serie
      kdo = j ? ' Pikomatu Junior' : ''
      h = +''
      if src.kind == :zad
        h << "= Zadání #{n}. série #{r}. ročníku#{kdo} =\n\n"
        h << "Termín odeslání: #{conv.meta[:termin]}\n\n" if conv.meta[:termin]
        if j
          h << "Pikomat Junior je **pro řešitele 3. až 6. tříd**, můžou se zúčastnit i mladší.\n\n"
          h << "Jak řešit, odevzdávat a další důležité informace ohledně Pikomatu Junior naleznete [[/junior|zde]].\n\n"
        else
          h << "Pravidla pro odevzdávání řešení najdete [[/pravidla|zde]]. O tom, jak řešení sepisovat, si můžete přečíst [[/jak_sepisovat|zde]] nebo se podívat na [[https://www.youtube.com/watch?v=03xRajBF5zA&feature=youtu.be|video]].\n\n"
        end
        h << "Adresa: Pikomat, KPMS MFF UK, Sokolovská 83, 186 75 Praha 8\n\n"
        pdfs = []
        if j && pdf_link(r, j, "zad#{n}.pdf")
          pdfs << "Zadání je k dispozici také ve formátu **[[#{pdf_link(r, j, "zad#{n}.pdf")}|pdf]]**. Velice **doporučujeme dětem dát toto vytištěné zadání**."
        elsif pdf_link(r, j, "zad#{n}.pdf")
          pdfs << "Samostatné zadání je k dispozici také ve formátu [[#{pdf_link(r, j, "zad#{n}.pdf")}|pdf]]."
        end
        pdfs.unshift("Celý leták najdete ve formátu pdf [[#{pdf_link(r, j, "letak#{n}.pdf")}|zde]].") if pdf_link(r, j, "letak#{n}.pdf")
        h << pdfs.join(' ') << "\n" unless pdfs.empty?
      else
        h << "= Vzorová řešení #{n}. série #{r}. ročníku#{kdo} =\n\n"
        h << "Zadání této série najdete [[#{url(r, j, "zad#{n}")}|zde]].\n\n"
        pdf = pdf_link(r, j, "vz#{n}.pdf")
        h << "Vzorová řešení jsou k dispozici také ve formátu [[#{pdf}|pdf]].\n" if pdf
      end
      h << "----\n\n"
    end

    def render(src)
      tex = File.read(src.path, encoding: 'UTF-8').scrub
      c = Converter.new(rocnik: src.rocnik, junior: src.junior)
      c.vz_link = url(src.rocnik, src.junior, "vz#{src.serie}") if src.kind == :zad && vz_published?(src)
      body = c.convert(tex)
      text = +''
      text << header(src, c)
      text << "$#{c.defs.join}$\n\n" unless c.defs.empty?
      text << body
      ["{{# tex2wiki: #{src.path.sub(%r{.*?/(?=\d\d[_/])}, '')} out=#{Digest::SHA256.hexdigest(text)[0, 12]} }}\n#{text}", c]
    end

    def vz_published?(src)
      flags(src.rocnik, src.junior)[src.serie].to_s.include?('r')
    end

    # :new, :stub, :ours, :edited
    def state(path)
      return :new unless File.exist?(path)
      cur = File.read(path, encoding: 'UTF-8').scrub
      return :stub if cur.gsub(/^=+[^=\n]*=+\s*$/, '') =~ REDIRECT_STUB
      m = cur.match(MARKER)
      return :edited unless m
      Digest::SHA256.hexdigest(cur.sub(MARKER, ''))[0, 12] == m[:out] ? :ours : :edited
    end

    TEMPLATE_SIZE = 1000

    def run(rocnik)
      changed = []
      sources(rocnik).each do |src|
        target = File.join(dir(src.rocnik, src.junior), "#{src.page}.wiki")
        rel = target.delete_prefix("#{@web}/")
        unless allowed?(src)
          say "  #{rel}: nezveřejněno (chybí '#{src.kind == :vz ? 'r' : 'z'}' v archiv/index.wiki)"
          next
        end
        wiki, conv = render(src)
        st = state(target)
        if st == :edited && !@force
          say "  #{rel}: ručně upravená stránka, přeskakuji (--force přepíše; --diff ukáže rozdíl)"
          next
        end
        if File.exist?(target) && File.read(target) == wiki
          images(src, conv).each { |i| say "  #{rel}: obrázek #{i}" } if @redo_images
          next
        end
        say "  #{rel}: #{{ new: 'nová', stub: 'místo odkazu na pdf', ours: 'aktualizace', edited: 'PŘEPSÁNÍ ruční úpravy' }[st]} (z #{src.path})"
        conv.warnings.each { |w| say "      varování: #{w}" }
        images(src, conv).each { |i| say "      obrázek #{i}" }
        if @write
          FileUtils.mkdir_p(File.dirname(target))
          File.write(target, wiki)
        end
        changed << rel
      end
      say(@write ? "zapsáno: #{changed.size}" : "(nanečisto, --write zapíše)") unless changed.empty?
      changed
    end

    # obrázek zad1.11 -> zad1.11.png (z png, nebo z metapost pdf zad1-11.pdf)
    def images(src, conv)
      todo = []
      conv.images.each do |name|
        dest = File.join(dir(src.rocnik, src.junior), "#{File.basename(name)}.png")
        next if File.exist?(dest) && !@redo_images
        png = find_file(src, "#{name}.png")
        pdf = find_file(src, "#{name.sub(/\.(\d+)\z/, '-\1')}.pdf") || find_file(src, "#{name}.pdf")
        unless png || pdf
          todo << "#{name}: CHYBÍ zdroj"
          next
        end
        todo << "#{name}.png <- #{png || pdf}"
        next unless @write
        FileUtils.mkdir_p(File.dirname(dest))
        if png
          FileUtils.cp(png, dest)
        else
          px = image_px(pdf, conv.image_cm(name))
          _, err, st = Open3.capture3('pdftoppm', '-png', '-singlefile', '-scale-to-x', px.to_s, '-scale-to-y', '-1',
                                      pdf, dest.delete_suffix('.png'))
          todo << "#{name}: pdftoppm selhal: #{err}" unless st.success?
        end
      end
      todo
    end

    PX_PER_CM = 38
    MAX_PX = 700

    # šířka PNG: velikost v letáku (nebo přirozená velikost PDF) * PX_PER_CM, nejvýš MAX_PX
    def image_px(pdf, cm)
      cm ||= begin
        out, = Open3.capture2('pdfinfo', pdf)
        out[/Page size:\s*([\d.]+)/, 1].to_f / 72 * 2.54
      end
      (cm * PX_PER_CM).round.clamp(40, MAX_PX)
    end

    # pořadí: adresář zdroje, jeho projekt, pak ostatní projekty ročníku (stejná větev junior/klasik napřed)
    def find_file(src, name)
      root = @srcs.find { |d| src.path.start_with?("#{d}/") }
      project = root && File.join(root, src.path.delete_prefix("#{root}/").split('/').first)
      local = [File.dirname(src.path), File.join(File.dirname(src.path), 'obrazky')]
      hit = local.map { |d| File.join(d, name) }.find { |f| File.file?(f) }
      hit ||= Dir.glob(File.join(project, '**', name)).min if project && File.directory?(project)
      hit || @srcs.flat_map { |d| Dir.glob(File.join(d, "#{src.rocnik}{_*,}", '**', name)) }
                  .min_by { |f| [junior_path?(f) == src.junior ? 0 : 1, f] }
    end

    def junior_path?(path)
      path =~ %r{/\d+_[^/]*j/|/(s|r|l|zad|vz)\d+j/|junior}i ? true : false
    end

    # shoda stávajících stránek s novým převodem (slova, bez hlavičky); kandidáti na přegenerování
    def check(rocnik)
      sources(rocnik).each do |src|
        target = File.join(dir(src.rocnik, src.junior), "#{src.page}.wiki")
        next unless File.exist?(target)
        st = state(target)
        next if st == :stub
        cur = words(File.read(target, encoding: 'UTF-8').scrub)
        new = words(render(src).first)
        nt = new.tally
        lcs = cur.tally.sum { |w, n| [n, nt[w].to_i].min }
        say format('  %-34s %-7s shoda %3d %%  (%d / %d slov)', target.delete_prefix("#{@web}/"), st,
                   cur.empty? ? 0 : 200 * lcs / (cur.size + new.size), cur.size, new.size)
      end
    end

    def words(wiki)
      body = wiki.sub(/\A.*?^----\s*$/m, '').sub(/\A.*?(?=^=+\s*Úloha)/m, '')
      body.gsub(/\{\{#.*?\}\}|#ul\d+|[~\u00a0]|\\,|\{\\rm\s*|\[\[#[^\]]*\]\]|,id=[^)]*/m, ' ')
          .gsub('--', '–').scan(/[[:alnum:]]+/)
    end

    def diff(rocnik, page, junior: false)
      src = sources(rocnik).find { |s| s.page == page && s.junior == junior } or abort "zdroj pro #{page} nenalezen"
      target = File.join(dir(rocnik, junior), "#{page}.wiki")
      wiki, = render(src)
      File.write(tmp = "#{target}.tex2wiki", wiki)
      system('diff', '-u', target, tmp)
      File.delete(tmp)
    end

    # nastaví příznak v archiv/index.wiki ({{archiv 41|zrv|…}})
    def publish(rocnik, serie, flag, junior: false)
      macro = junior ? 'archiv_junior' : 'archiv'
      idx = File.read(index_path)
      re = /\{\{#{macro}\s+#{rocnik}\|([^}]*)\}\}/
      line = idx[re] or abort "v archiv/index.wiki chybí {{#{macro} #{rocnik}|…}}"
      fl = idx[re, 1].split('|', -1)
      fl[serie - 1] = (fl[serie - 1].to_s.chars | flag.chars).sort_by { |ch| 'znrv'.index(ch) || 9 }.join
      new_line = line.sub(/\|.*\}\}\z/, "|#{fl.join('|')}}}")
      say "#{line}  ->  #{new_line}"
      File.write(index_path, idx.sub(line, new_line)) if @write
    end
  end
end
