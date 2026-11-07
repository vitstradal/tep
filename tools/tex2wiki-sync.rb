# tex2wiki sync: najde TeXy zadání a vzoráků, převede je a zapíše do web repa.
#
# Co se smí zveřejnit, říká archiv/index.wiki ({{archiv 41|zrv|zr|z}}):
# z = zadání, r = vzorové řešení. Ručně upravené stránky se nepřepisují.
require 'digest'
require 'fileutils'
require 'open3'
require 'date'

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
      @published = []
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

    VIDEO = 'https://www.youtube.com/watch?v=03xRajBF5zA&feature=youtu.be'
    ADRESA = 'Pikomat, KPMS MFF UK, Sokolovská 83, 186 75 Praha 8'
    PDF_ICO = '{{ico fa-file-pdf-o}}'

    # odkaz na PDF, které je na webu, nebo ho pdfs zkopíruje z překlepu
    def pdf_url(src, name)
      file = pdf_files(src).find { |n, _| n == name } or return
      url(src.rocnik, src.junior, name) if file[1] || File.exist?(File.join(dir(src.rocnik, src.junior), name))
    end

    def header(src, conv)
      r, j, n = src.rocnik, src.junior, src.serie
      kdo = j ? ' Pikomatu Junior' : ''
      pdf = ->(name, text) { (u = pdf_url(src, name)) && "#{PDF_ICO} [[#{u}|#{text}]]" }
      h = +''
      if src.kind == :zad
        h << "= Zadání #{n}. série #{r}. ročníku#{kdo} =\n\n"
        h << "Termín odeslání: #{conv.meta[:termin]}\n\n" if conv.meta[:termin]
        if j
          h << "Pikomat Junior je **pro řešitele 3. až 6. tříd**, můžou se zúčastnit i mladší. " \
               "[[/junior|Jak řešit a odevzdávat]] a další důležité informace najdeš na stránce Juniora.\n\n"
        else
          h << "Než začneš psát, pozorně si přečti [[/pravidla|pravidla pro odevzdávání řešení]] a " \
               "[[/jak_sepisovat|návod, jak řešení sepsat]], nebo se podívej na [[#{VIDEO}|krátké video]].\n\n"
        end
        h << "Řešení posílej na adresu: #{ADRESA}\n\n"
        zadani = if j && (u = pdf_url(src, "zad#{n}.pdf"))
                   "#{PDF_ICO} **[[#{u}|Zadání k vytištění]]**: dětem ho velice doporučujeme dát vytištěné."
                 else
                   pdf.call("zad#{n}.pdf", 'zadání')
                 end
        letak = letaky(r, j)[n]
        links = [zadani, letak && pdf.call(letak[0], 'celý leták')]
      else
        h << "= Vzorová řešení #{n}. série #{r}. ročníku#{kdo} =\n\n"
        h << "K těmto řešením patří [[#{url(r, j, "zad#{n}")}|zadání #{n}. série]].\n\n"
        links = [pdf.call("vz#{n}.pdf", 'vzorová řešení')]
      end
      links.compact!
      h << links.join(' · ') << "\n\n" unless links.empty?
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

    # :new, :empty, :stub, :ours, :edited
    def state(path)
      return :new unless File.exist?(path)
      cur = File.read(path, encoding: 'UTF-8').scrub
      return :empty if cur.strip.empty?
      return :stub if cur.gsub(/^=+[^=\n]*=+\s*$/, '') =~ REDIRECT_STUB
      m = cur.match(MARKER)
      return :edited unless m
      Digest::SHA256.hexdigest(cur.sub(MARKER, ''))[0, 12] == m[:out] ? :ours : :edited
    end

    TEMPLATE_SIZE = 1000

    STATES = { new: 'nová', empty: 'místo prázdné stránky', stub: 'místo odkazu na pdf', ours: 'aktualizace', edited: 'PŘEPSÁNÍ ruční úpravy' }.freeze

    # mode :gen jen nové stránky, :regen i vygenerované, které se změnily; ručně upravené jen s force
    # vrací {zapsané: [...], změněné ve zdroji: [...], ruční: [...], nezveřejněné: [...]}
    # only: [[junior, 'zad2'], …] omezí běh na tyto stránky
    def run(rocnik, mode: :regen, only: nil)
      res = Hash.new { |h, k| h[k] = [] }
      allowed = mode == :gen ? %i[new empty stub] : %i[new empty stub ours]
      allowed += [:edited] if @force
      sources(rocnik).each do |src|
        next if only && !only.include?([src.junior, src.page])
        target = File.join(dir(src.rocnik, src.junior), "#{src.page}.wiki")
        rel = target.delete_prefix("#{@web}/")
        unless allowed?(src)
          res[:unpublished] << "#{rocnik}/#{src.junior ? 'j' : ''}#{src.serie}#{src.kind == :vz ? 'r' : 'z'}"
          next
        end
        pdfs(src, res).each { |p| say "  #{rel}: pdf #{p}" }
        wiki, conv = render(src)
        if File.exist?(target) && File.read(target) == wiki
          images(src, conv).each { |i| say "  #{rel}: obrázek #{i}" }
          next
        end
        st = state(target)
        unless allowed.include?(st) || (st == :ours && @published.include?([src.rocnik, src.junior, src.serie]))
          res[st == :edited ? :edited : :outdated] << rel
          next
        end
        say "  #{rel}: #{STATES[st]} (z #{src.path})"
        conv.warnings.each { |w| say "      varování: #{w}" }
        images(src, conv).each { |i| say "      obrázek #{i}" }
        if @write
          FileUtils.mkdir_p(File.dirname(target))
          File.write(target, wiki)
        end
        res[:written] << rel
      end
      res
    end

    # obrázek zad1.11 -> zad1.11.png (z png, nebo z pdf zad1-11.pdf / zad1.11.pdf)
    def images(src, conv)
      todo = []
      conv.images.each do |name|
        dest = File.join(dir(src.rocnik, src.junior), "#{File.basename(name)}.png")
        next if File.exist?(dest) && !@redo_images
        png = find_file(src, "#{name}.png")
        pdf = find_file(src, "#{name.tr('.', '-')}.pdf") || find_file(src, "#{name}.pdf")
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

    # [jméno na webu, zdroj v překlepu nebo nil]; leták podle série, jejíž zadání obsahuje
    def pdf_files(src)
      n = src.serie
      return [["vz#{n}.pdf", pdf_source(src, "vz#{n}.pdf")]] if src.kind == :vz
      [["zad#{n}.pdf", pdf_source(src, "zad#{n}.pdf")], letaky(src.rocnik, src.junior)[n]].compact
    end

    # zadN.pdf, letakM.pdf, vzN.pdf z překlepu vedle stránky; novější z překlepu přepíše, nic nemaže
    def pdfs(src, res)
      rel_dir = dir(src.rocnik, src.junior).delete_prefix("#{@web}/")
      res[:pdf_missing] << "#{rel_dir}/letak*.pdf se zadáním #{src.serie}. série" if src.kind == :zad && !letaky(src.rocnik, src.junior)[src.serie]
      pdf_files(src).filter_map do |name, from|
        dest = File.join(dir(src.rocnik, src.junior), name)
        unless from
          res[:pdf_missing] << "#{rel_dir}/#{name}" unless File.exist?(dest)
          next
        end
        next if File.exist?(dest) && FileUtils.compare_file(from, dest)
        if @write
          FileUtils.mkdir_p(File.dirname(dest))
          FileUtils.cp(from, dest)
        end
        res[:pdf] << "#{rel_dir}/#{name}"
        "#{name} <- #{from}"
      end.uniq
    end

    # kořen projektu zdroje, pak kořeny ostatních projektů ročníku
    def pdf_source(src, name)
      root = @srcs.find { |d| src.path.start_with?("#{d}/") } or return
      project = File.join(root, src.path.delete_prefix("#{root}/").split('/').first)
      [project, *projects(src.rocnik, src.junior)].map { |d| File.join(d, name) }.find { |f| File.file?(f) }
    end

    def projects(rocnik, junior)
      @srcs.flat_map { |d| Dir.glob(File.join(d, "#{rocnik}_*")).sort }.select { |d| junior_path?("#{d}/") == junior }
    end

    # {série => [letakM.pdf, zdroj v překlepu nebo nil]} podle „Zadání úloh/příkladů N. série R. ročníku“ v PDF
    def letaky(rocnik, junior)
      @letaky ||= {}
      @letaky[[rocnik, junior]] ||= begin
        files = Dir.glob(File.join(dir(rocnik, junior), 'letak*.pdf')).to_h { |f| [File.basename(f), nil] }
        projects(rocnik, junior).reverse_each do |d|
          Dir.glob(File.join(d, 'letak*.pdf')).each { |f| files[File.basename(f)] = f }
        end
        files.each_with_object({}) do |(name, from), map|
          text = pdf_text(from || File.join(dir(rocnik, junior), name))
          text.scan(/Zadání\s+\S+\s+(\d+)\.\s*série\s+#{rocnik}\.\s*ročníku/).flatten.map(&:to_i).uniq
              .each { |n| map[n] ||= [name, from] }
        end
      end
    end

    def pdf_text(path)
      out, = Open3.capture2('pdftotext', '-q', path, '-')
      out.force_encoding('UTF-8').scrub
    end


    # šířka PNG: velikost v letáku (nebo přirozená velikost PDF) * PX_PER_CM, nejvýš MAX_PX
    def image_px(pdf, cm)
      cm ||= begin
        out, = Open3.capture3('pdfinfo', pdf)
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
      src = sources(rocnik).find { |s| s.page == page && s.junior == !!junior } or abort "zdroj pro #{page} nenalezen"
      target = File.join(dir(rocnik, junior), "#{page}.wiki")
      wiki, = render(src)
      File.write(tmp = "#{target}.tex2wiki", wiki)
      say 'Stránka je stejná jako nový převod z TeXu.' if system('diff', '-u', target, tmp)
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
      @published << [rocnik, junior, serie]
      File.write(index_path, idx.sub(line, new_line)) if @write
    end
  end
  # zrcadlo překlepu: touch refresh, kontejner preklep-mirror po exportu zapíše stamp
  module Mirror
    BASE = '/home/pikomat/preklep-mirror.d'

    def self.refresh(base = BASE, timeout: 180, poll: 2, out: $stdout)
      trigger = File.join(base, 'refresh')
      stamp = File.join(base, 'stamp')
      return unless File.writable?(trigger)
      FileUtils.touch(trigger)
      asked = File.mtime(trigger)
      out.print 'Obnovuji zrcadlo překlepu'
      deadline = Time.now + timeout
      until File.exist?(stamp) && File.mtime(stamp) >= asked
        if Time.now > deadline
          old = File.exist?(stamp) ? File.mtime(stamp).strftime('%-d. %-m. %H:%M') : '?'
          out.puts "\nZrcadlo neodpovídá (docker logs preklep-mirror), pokračuji se zrcadlem z #{old}."
          return
        end
        out.print '.'
        sleep poll
      end
      out.puts " hotovo (#{File.read(stamp).lines.first.to_s.strip})"
    end
  end

  # vlastní klon web repa, se kterým tex2wiki pracuje
  class Repo
    ORIGINS = ['/home/www/git/web.git', 'ssh+git://pikomat.mff.cuni.cz/home/www/git/web.git'].freeze

    def self.current_rocnik(today = Date.today)
      today.year - 1984 - (today.month >= 9 ? 0 : 1)
    end

    def initialize(dir)
      @dir = dir
    end

    def git(*args)
      out, st = Open3.capture2e('git', '-C', @dir, *args)
      abort "git #{args.join(' ')} selhal:\n#{out}" unless st.success?
      out
    end

    def prepare
      if File.directory?(File.join(@dir, '.git'))
        if dirty?
          puts "V #{@dir} jsou necommitnuté změny z minula, pokračuji nad nimi (--commit nebo --clean)."
        else
          git('pull', '-q', '--ff-only')
        end
      else
        origin = ORIGINS.find { |o| o.include?('://') || File.directory?(o) }
        puts "Klonuji #{origin} do #{@dir}"
        out, st = Open3.capture2e('git', 'clone', '-q', origin, @dir)
        abort out unless st.success?
      end
    end

    def dirty?
      !git('status', '--porcelain').empty?
    end

    # ročníky z archiv/index.wiki, letošní a loňský
    def recent_rocniky
      cur = self.class.current_rocnik
      File.read(File.join(@dir, 'archiv/index.wiki')).scan(/\{\{archiv(?:_junior)?\s+(\d+)\|/).flatten.map(&:to_i)
          .uniq.select { |r| r >= cur - 1 }.sort
    end

    def commit_and_push
      abort "#{@dir} neexistuje, nejdřív --gen" unless File.directory?(@dir)
      git('add', '-A', 'archiv')
      files = git('diff', '--cached', '--name-only').lines.map(&:chomp)
      return files if files.empty?
      pages = files.grep(/\.(wiki|pdf)\z/).map { |f| f.delete_prefix('archiv/').delete_suffix('.wiki') }
      git('commit', '-q', '-m', "archiv: #{pages.join(', ')} (tex2wiki)")
      git('pull', '-q', '--rebase')
      git('push', '-q')
      files
    end

    def clean
      git('fetch', '-q')
      git('reset', '-q', '--hard', '@{u}')
      git('clean', '-qfd')
    end
  end
end
