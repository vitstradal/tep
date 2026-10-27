#!/usr/bin/env ruby
##
# tex2wiki.rb — převod TeXových zadání a vzoráků Pikomatu na trac-wiki stránky.
#
# Makra jsou v tools/tex2wiki-macros.rb; nové makro = jeden řádek tam.
#
# Použití:
#   tex2wiki.rb soubor.tex [--rocnik 41] [--junior]   wiki na stdout
#
# Převodník pracuje přímo nad TeXem (bez ttm/m4): text, skupiny {…},
# matematika $…$ / $$…$$ zůstává TeXová (wiki ji kreslí MathJaxem).
require 'strscan'

module Tex2Wiki
  Macro = Struct.new(:name, :arity, :mode, :body, :opt)

  class Registry
    attr_reader :text_macros, :math_macros

    def initialize
      @text_macros = {}
      @math_macros = {}
    end

    # text makro: body je String se %1..%9 (převedené argumenty) nebo blok |ctx, *raw_args|
    def macro(name, arity = 0, body = nil, &blk)
      @text_macros[name.to_s] = Macro.new(name.to_s, arity, :text, blk || body)
    end

    # makro v matematice: nahradí se TeXovým textem (argumenty %1..%9 surově)
    def math(name, body, arity = 0)
      @math_macros[name.to_s] = Macro.new(name.to_s, arity, :math, body)
    end

    def ignore(*names)
      names.flatten.each { |n| macro(n, 0, '') }
    end

    # makra s rozměrem (\hskip 1cm plus 1fil)
    def ignore_dimen(*names)
      names.flatten.each { |n| macro(n, 0) { |c| c.skip_dimen; '' } }
    end

    def ignore_number(*names)
      names.flatten.each { |n| macro(n, 0) { |c| c.skip_number; '' } }
    end

    def text_char(map)
      map.each { |n, s| macro(n, 0, s) }
    end
  end

  def self.registry
    @registry ||= begin
      r = Registry.new
      @pending&.each { |blk| r.instance_eval(&blk) }
      r
    end
  end

  def self.macros(&blk)
    (@pending ||= []) << blk
    @registry&.instance_eval(&blk)
  end

  class Converter
    DIMEN = /\s*-?(\d+(\.\d*)?|\.\d+)\s*(pt|cm|mm|em|ex|in|bp|sp|pc|dd|cc|fil+|true\s*\w+)|\s*-?(\d+(\.\d*)?|\.\d+)?\s*\\[hv]size|\s*\\baselineskip/
    PARA = "\n\n"

    attr_reader :meta, :warnings, :images, :defs
    attr_accessor :rocnik, :junior, :vz_link

    def initialize(rocnik: nil, junior: false, registry: Tex2Wiki.registry)
      @reg = registry
      @rocnik = rocnik
      @junior = junior
      @meta = {}
      @warnings = []
      @images = []
      @labels = {}
      @defs = []
      @list = []
      @image_cm = {}
      @footnotes = []
    end

    # šířka obrázku v letáku v cm (podle \obrazky{…|8cm|…} nebo width u \XeTeXpdffile)
    def image_cm(name)
      @image_cm[name]
    end

    def fdir
      "archiv/rocnik#{@rocnik}#{@junior ? '/junior' : ''}"
    end

    def convert(src)
      src = strip_comments(src)
      src.scan(/\\obrazky\s*\{([^{}]*)\}/) { |(spec)| spec.split(';').each { |it| label_for(it) } }
      @s = StringScanner.new(src)
      out = parse_text(nil)
      out << flush_footnotes
      cleanup(out)
    end

    # --- vstup -------------------------------------------------------------

    def strip_comments(src)
      src.gsub(/\r\n?/, "\n").lines.map do |l|
        next nil if l =~ /\A[ \t]*(?<!\\)%/
        l.sub(/(?<!\\)%.*/, '')
      end.compact.join
    end

    def warn(msg)
      @warnings << msg unless @warnings.include?(msg)
    end

    def skip_spaces(newline: true)
      @s.scan(newline ? /[ \t]*\n?[ \t]*/ : /[ \t]*/)
    end

    def skip_dimen
      @s.scan(/\s*=?/)
      @s.scan(DIMEN)
      while @s.scan(/\s*(plus|minus)/)
        @s.scan(DIMEN)
      end
      skip_spaces(newline: false)
    end

    def skip_number
      @s.scan(/\s*=?\s*-?\s*\d+\s?/)
    end

    # jeden TeXový argument: {skupina} nebo jeden znak / řídicí sekvence
    def read_arg
      @s.scan(/\s*/)
      if @s.scan(/\{/)
        read_group_raw
      elsif (cs = @s.scan(/\\([a-zA-Z]+|.)/))
        cs
      else
        @s.getch.to_s
      end
    end

    # {…} jen když následuje
    def skip_brace_arg
      read_arg if @s.check(/\s*\{/)
      nil
    end

    def read_opt_arg
      return nil unless @s.check(/\s*\[/)
      @s.scan(/\s*\[/)
      raw = +''
      until @s.eos? || @s.scan(/\]/)
        raw << (@s.scan(/\{/) ? "{#{read_group_raw}}" : @s.getch)
      end
      raw
    end

    def read_group_raw
      depth = 1
      raw = +''
      until @s.eos?
        if (t = @s.scan(/\\./m))
          raw << t
        elsif @s.scan(/\{/)
          depth += 1
          raw << '{'
        elsif @s.scan(/\}/)
          depth -= 1
          return raw if depth.zero?
          raw << '}'
        else
          raw << @s.getch
        end
      end
      warn('neuzavřená skupina {')
      raw
    end

    # převod kusu TeXu (argument makra) jiným skenerem
    def conv(str)
      saved = @s
      @s = StringScanner.new(str)
      parse_text(nil)
    ensure
      @s = saved
    end

    # --- text --------------------------------------------------------------

    def parse_text(stop)
      out = +''
      until @s.eos?
        break if stop && @s.check(stop)
        if @s.scan(/\$\$/)
          out << "\n\n$$#{read_math('$$')}$$\n\n"
        elsif @s.scan(/\$/)
          out << "$#{read_math('$')}$"
        elsif @s.scan(/\\\\/)
          out << "\\\\\n"
        elsif (cs = @s.scan(/\\[a-zA-Z]+/))
          out << control_word(cs[1..])
        elsif (cs = @s.scan(/\\./m))
          out << control_symbol(cs[1])
        elsif @s.scan(/\{/)
          out << group
        elsif @s.scan(/\}/)
          warn('nadbytečná }')
        elsif @s.scan(/~/)
          out << "\u00a0"
        elsif @s.scan(/---/)
          out << '—'
        elsif @s.scan(/--/)
          out << '–'
        elsif @s.scan(/\n[ \t]*\n\s*/)
          out << PARA
        elsif @s.scan(/\n[ \t]*/)
          out << "\n"
        else
          out << (@s.scan(/[^\\${}\n~-]+|-/) || @s.getch).to_s
        end
      end
      out
    end

    FONTS = { 'bf' => '**', 'it' => "''", 'sl' => "''", 'em' => "''", 'sf' => '', 'rm' => '', 'tt' => '`' }.freeze

    def group
      inner = read_group_raw
      if inner =~ /\A\s*\\(bf|it|sl|em|sf|rm|tt)(?![a-zA-Z])\s*(.*)\z/m
        mark = FONTS[$1]
        body = conv($2).strip
        return body if body.empty?
        "#{mark}#{body}#{mark}"
      else
        conv(inner)
      end
    end

    def control_symbol(ch)
      case ch
      when ',', '~', ' ', "\n" then ' '
      when '-', '/' then ''
      when '%', '&', '#', '$', '_', '{', '}' then ch
      else
        warn("neznámý symbol \\#{ch}")
        "\\#{ch}"
      end
    end

    def control_word(name)
      m = @reg.text_macros[name]
      unless m
        return capture_def if %w[def gdef edef xdef].include?(name)
        if name == 'let'
          @s.scan(/\s*\\([a-zA-Z]+|.)\s*=?\s*(\\([a-zA-Z]+|.)|.)/m)
          return ''
        end
        warn("neznámé makro \\#{name}")
        skip_spaces(newline: false)
        return "\\#{name}"
      end
      skip_spaces(newline: false) if m.arity.zero?
      args = Array.new(m.arity) { read_arg }
      case m.body
      when Proc then m.body.call(self, *args).to_s
      when nil then ''
      else
        m.body.gsub(/%(\d)/) { conv(args[$1.to_i - 1].to_s) }
      end
    end

    NOT_MATHJAX = /\\(halign|valign|vbox|vtop|noalign|hrule|vskip|centerline|par|leaders|XeTeX|medskip|bigskip|smallskip|noindent|hfil|vfil|setbox|ifnum|advance|immediate|write|csname|hss|hskip|vrule|strut|kern|raise|lower|leaders)\b|\\hbox\s*to/

    # \def\jmeno#1{tělo} v textu -> preambule $\def…$ pro MathJax
    def capture_def
      name = @s.scan(/\s*\\[a-zA-Z]+/).to_s.strip
      params = @s.scan(/[^{]*/)
      @s.scan(/\{/)
      body = read_group_raw
      if @reg.math_macros.key?(name[1..]) || @reg.text_macros.key?(name[1..])
        # registr má přednost
      elsif body =~ NOT_MATHJAX
        warn("#{name} nejde do MathJaxu, vynecháno")
      else
        @defs << "\\def#{name}#{params}{#{body}}"
      end
      ''
    end

    # --- matematika --------------------------------------------------------

    def read_math(delim)
      out = +''
      until @s.eos?
        return out if @s.scan(delim == '$$' ? /\$\$/ : /\$/)
        if (cs = @s.scan(/\\[a-zA-Z]+/))
          out << math_word(cs[1..])
        elsif (t = @s.scan(/\\./m))
          out << t
        else
          out << (@s.scan(/[^\\$]+/) || @s.getch).to_s
        end
      end
      warn("neuzavřená matematika #{delim}")
      out
    end

    def math_word(name)
      m = @reg.math_macros[name]
      return "\\#{name}" unless m
      args = Array.new(m.arity) { read_arg }
      body = m.body.is_a?(Proc) ? m.body.call(self, *args) : m.body.gsub(/%(\d)/) { args[$1.to_i - 1].to_s }
      # \m následovaný písmenem by se slepil (\,{\rm m}x je OK, ale \cdotx ne)
      body
    end

    # argument {…}, nebo text do konce odstavce (\podnadpis Nadpis\par)
    def read_arg_or_par
      return read_arg if @s.check(/[ \t]*\{/)
      raw = @s.scan_until(/\n[ \t]*\n|\\par\b|\z/).to_s
      raw.sub(/(\n[ \t]*\n|\\par)\z/, '')
    end

    def stop!
      @s.terminate
      ''
    end

    def read_filename
      @s.scan(/\s*/)
      name = @s.scan(/"[^"]*"|[^\s{}\\]+/).to_s.delete('"')
      return warn('\\XeTeXpdffile bez jména souboru') && '' if name.empty?
      if (key = @s.scan(/\s*(width|height|scaled)\s*/))
        dim = @s.scan(DIMEN) || @s.scan(/\d+/)
        @image_cm[name.sub(/\.(pdf|png|jpe?g)\z/i, '')] = dimen_cm(dim) if key.strip == 'width'
      end
      name
    end

    HSIZE_CM = 17.0

    # TeXový rozměr v cm ("8cm", "45mm", ".45\hsize"), nil když nejde určit
    def dimen_cm(dim)
      d = dim.to_s.strip
      return HSIZE_CM * (d[/[\d.]+/] || 1).to_f if d =~ /size|width/
      n = d[/-?[\d.]+/]&.to_f or return nil
      { 'cm' => 1, 'mm' => 0.1, 'pt' => 0.0351, 'bp' => 0.0353, 'in' => 2.54, 'em' => 0.35 }[d[/[a-z]+/]]&.*(n)
    end

    # konec zadání úlohy; s vz_link odkaz na vzorové řešení
    def ulend
      n = @meta[:ul]
      link = @vz_link && n ? "\n\n[[#{@vz_link}#ul#{n}|→ vzorové řešení]]" : ''
      "#{flush_footnotes}#{link}\n\n"
    end

    # plain \footnote{značka}{text} i LaTeXové \footnote{text}; text se vypíše na konci úlohy
    def footnote
      first = read_arg
      if @s.check(/\s*\{/)
        mark, text = conv(first).strip, read_arg
      else
        mark, text = '*' * (@footnotes.size + 1), first
      end
      @footnotes << "#{mark} #{conv(text).strip.gsub(/\s*\n\s*/, ' ')}"
      mark
    end

    def flush_footnotes
      return '' if @footnotes.empty?
      notes = @footnotes.map { |f| "''#{f}''\n\n" }.join
      @footnotes = []
      "\n\n#{notes}"
    end

    # \halign{šablona\cr řádek&řádek\cr …} -> wiki tabulka
    def halign(raw)
      rows = raw.split(/\\cr(?:cr)?\b/).map(&:strip).reject(&:empty?)
      tmpl = rows.first&.include?('#') ? rows.shift : ''
      math = tmpl.include?('$')
      out = rows.filter_map do |r|
        r = r.gsub(/\\noalign\s*\{[^{}]*\}|\\(hline|hthickline|cara|omit|hfil|hfill|strut)\b/, '').strip
        next if r.empty?
        cells = r.split(/(?<!\\)&/).map do |cell|
          cell = cell.strip
          cell = "$#{cell}$" if math && !cell.empty? && !cell.include?('$')
          conv(cell).strip.gsub("\n", ' ')
        end
        Converter.line("|| #{cells.join(' || ')} ||")
      end
      "\n#{out.join}\n\n"
    end

    # LaTeXová prostředí; figure/table/center jsou jen obal
    def env_begin(env)
      read_opt_arg
      case env
      when 'tabular', 'tabular*'
        read_arg
        body = @s.scan_until(/\\end\s*\{tabular\*?\}/).to_s.sub(/\\end\s*\{tabular\*?\}\z/, '')
        halign(body.gsub(/\\\\(\[[^\]]*\])?/, '\cr'))
      when 'itemize' then list_begin('*')
      when 'enumerate' then list_begin('1.')
      when 'figure', 'figure*', 'table', 'table*', 'center', 'minipage' then "\n\n"
      else
        warn("neznámé prostředí #{env}")
        ''
      end
    end

    def env_end(env)
      %w[itemize enumerate].include?(env) ? list_end : "\n\n"
    end

    def includegraphics
      opts = read_opt_arg.to_s
      file = read_arg.strip
      width = opts[/width\s*=\s*([^,\]]+)/, 1]
      @image_cm[file.sub(/\.(pdf|png|jpe?g)\z/i, '')] = dimen_cm(width) if width
      image(file)
    end

    # --- obrázky -----------------------------------------------------------

    # položka \obrazky: "zad1.11|zad111" nebo "zad3.11|8cm|popisek"
    def label_for(item)
      file, *rest = item.split('|').map(&:strip)
      return nil if file.nil? || file.empty?
      label = rest.size == 1 && rest[0] !~ /\A[\d.]+\s*(cm|mm|pt|em)\z/ ? rest[0] : File.basename(file).delete('.')
      @labels[label] ||= @labels.size + 1
      @image_cm[file.sub(/\.(pdf|png|jpe?g)\z/i, '')] ||= dimen_cm(rest[0]) if rest.size >= 2
      [file, label, rest.size >= 2 ? rest[1..].join('|') : nil]
    end

    def image(file, label = nil)
      file = file.to_s.strip
      if file.empty? || file.start_with?('\\')
        warn("divné jméno obrázku: #{file.inspect}")
        return ''
      end
      @images << file.sub(/\.(pdf|png|jpe?g)\z/i, '') unless @images.include?(file.sub(/\.(pdf|png|jpe?g)\z/i, ''))
      png = File.basename(file).sub(/\.(pdf|png|jpe?g)\z/i, '')
      ext = file =~ /\.(png|jpe?g)\z/i ? '' : '.png'
      id = label ? ",id=#{label}" : ''
      "#{Converter.line("[[Image(#{fdir}/#{png}#{ext}#{id})]]")}\n"
    end

    def obrazky(spec)
      spec.split(';').map do |it|
        file, label, caption = label_for(it)
        next '' unless file
        cap = caption && conv(caption).strip
        image(file, label) + (cap && !cap.empty? ? "**#{cap}**\n\n" : '')
      end.join
    end

    def obref(label)
      n = @labels[label]
      warn("\\obref{#{label}} bez obrázku") unless n
      "[[##{label}|#{n || label}]]"
    end

    # --- seznamy -----------------------------------------------------------

    def list_begin(marker)
      @list.push(marker)
      "\n"
    end

    def in_var_list?
      @list.last == :var
    end

    def list_item_free(label)
      Converter.line("#{' ' * [@list.size, 1].max}* #{conv(label).strip} ")
    end

    def list_item(label = nil)
      marker = @list.last.is_a?(String) ? @list.last : '*'
      Converter.line("#{' ' * @list.size}#{marker} #{label ? "#{conv(label).strip} " : ''}")
    end

    def list_end
      @list.pop
      "\n\n"
    end

    # --- výstup ------------------------------------------------------------

    LINE_START = /\A([*-]\s|[aAIi\d]+\.\s|=|>|\|\||----)/
    MARK = "\u0001"

    # řádek, který vyrobilo makro (nadpis, obrázek, položka seznamu)
    def self.line(str)
      "\n#{MARK}#{str}"
    end

    def cleanup(out)
      res = []
      item = false
      out.split("\n", -1).each do |l|
        if l.start_with?(MARK)
          l = l.delete(MARK).rstrip
          item = l =~ /\A\s+([*-]|[a\d]+\.)\s/
          res << l
          next
        end
        l = l.strip
        item = false if l.empty?
        if (item || l =~ LINE_START) && res.last && !res.last.empty?
          res[-1] = "#{res[-1]} #{l}"
        else
          l = "\u2060#{l}" if l =~ LINE_START
          res << l
        end
      end
      res.join("\n").gsub(/\n{3,}/, "\n\n")
         .gsub(/^( +([*-]|[a\d]+\.) .*)\n\n(?= +([*-]|[a\d]+\.) )/, "\\1\n")
         .sub(/\A\n+/, '').rstrip + "\n"
    end
  end

  # celá stránka: hlavička se zdrojem + preambule s \def + tělo
  def self.page(tex, rocnik:, junior: false, source: nil, header: nil)
    c = Converter.new(rocnik: rocnik, junior: junior)
    body = c.convert(tex)
    out = +''
    out << "{{# tex2wiki: #{source} }}\n" if source
    out << header.call(c) if header
    out << "$#{c.defs.join}$\n\n" unless c.defs.empty?
    out << body
    [out, c]
  end
end

require_relative 'tex2wiki-macros'

if $PROGRAM_NAME == __FILE__
  require 'optparse'
  require_relative 'tex2wiki-sync'
  opt = { web: File.expand_path('~/tex2wiki-web'), srcs: %w[/home/pikomat/preklep-mirror /home/pikomat], publish: [] }
  parser = OptionParser.new do |o|
    o.banner = <<~USAGE
      usage: tex2wiki.rb --gen [ROCNIK…]        vytvoří nové stránky zveřejněných sérií (nic nepřepíše)
             tex2wiki.rb --regen [ROCNIK…]      i stránky, jejichž TeX se změnil (ruční úpravy ne)
             tex2wiki.rb --regen --force 42 zad2 [--junior]   přepíše jen tuto stránku i s ručními úpravami
             tex2wiki.rb --publish 42/2r        zveřejní sérii (z zadání, r řešení, j2r junior) a --gen
             tex2wiki.rb --commit               commit + push do webu
             tex2wiki.rb --clean                zahodí necommitnuté změny v klonu
      Bez ROCNIK bere letošní a loňský ročník. Klon webu: ~/tex2wiki-web (udělá si ho sám).

      ladění: tex2wiki.rb soubor.tex [--rocnik N] [--junior]   převod na stdout
              tex2wiki.rb check ROCNIK                          shoda stránek s novým převodem
              tex2wiki.rb diff ROCNIK zad3|vz3 [--junior]       rozdíl stránky a nového převodu
    USAGE
    o.on('--gen') { opt[:cmd] = :gen }
    o.on('--regen') { opt[:cmd] = :regen }
    o.on('--publish SPEC') { |v| opt[:publish] << v; opt[:cmd] ||= :gen }
    o.on('--commit') { opt[:cmd] = :commit }
    o.on('--clean') { opt[:cmd] = :clean }
    o.on('--force', 'přepsat i ručně upravené stránky (s --regen)') { opt[:force] = true }
    o.on('--redo-images', 'znovu vyrobit i existující PNG') { opt[:redo_images] = true }
    o.on('--web DIR', 'klon web repa') { |v| opt[:web] = File.expand_path(v) }
    o.on('--src DIR', 'adresář se zdroji (opakovatelné)') { |v| (opt[:src] ||= []) << v }
    o.on('--rocnik N', Integer) { |v| opt[:rocnik] = v }
    o.on('--junior') { opt[:junior] = true }
  end
  parser.parse!
  opt[:srcs] = opt[:src] if opt[:src]
  repo = Tex2Wiki::Repo.new(opt[:web])
  sync = -> { Tex2Wiki::Sync.new(web: opt[:web], srcs: opt[:srcs], write: true, force: opt[:force],
                                 redo_images: opt[:redo_images]) }
  me = 'tex2wiki.rb'

  case opt[:cmd]
  when :gen, :regen
    pages, nums = ARGV.partition { |a| a =~ /\A(zad|vz)\d+\z/ }
    rocniky = nums.map { |a| Integer(a) }
    abort 'Stránku zadej i s ročníkem: --regen --force 42 zad2' if !pages.empty? && rocniky.empty?
    Tex2Wiki::Mirror.refresh unless opt[:src]
    repo.prepare
    rocniky = repo.recent_rocniky if rocniky.empty?
    only = pages.map { |p| [!!opt[:junior], p] } unless pages.empty?
    s = sync.call
    opt[:publish].each do |spec|
      m = spec.match(%r{\A(?:(\d+)/)?(j)?(\d+)([zr]+)\z}) or abort "--publish #{spec}: čekám např. 42/2r nebo 42/j2z"
      r = m[1] ? m[1].to_i : Tex2Wiki::Repo.current_rocnik
      s.publish(r, m[3].to_i, m[4], junior: !m[2].nil?)
      rocniky |= [r]
    end
    res = Hash.new { |h, k| h[k] = [] }
    rocniky.sort.each do |r|
      s.run(r, mode: opt[:cmd], only: only).each { |k, v| res[k].concat(v) }
    end
    puts
    puts "Zapsáno: #{res[:written].size} stránek." unless res[:written].empty?
    puts "Nic nového." if res[:written].empty? && opt[:publish].empty?
    puts "TeX se změnil, přepíše --regen: #{res[:outdated].join(', ')}" unless res[:outdated].empty?
    unless res[:edited].empty?
      puts "Ručně upravené, nepřepisuji: #{res[:edited].join(', ')}"
      puts "  (rozdíl: #{me} diff 42 zad2 [--junior]; přepsat jen ji: #{me} --regen --force 42 zad2 [--junior])"
    end
    puts "Nezveřejněné série se zdrojem: #{res[:unpublished].join(' ')}  (zveřejní --publish ROCNIK/SERIE)" unless res[:unpublished].empty?
    puts
    if repo.dirty?
      puts 'Další krok:'
      puts "  zkontroluj změny:  git -C #{opt[:web]} status; git -C #{opt[:web]} diff"
      puts "  pak buď:           #{me} --commit   (commit a push, tím je to na webu)"
      puts "  nebo:              #{me} --clean    (vše zahodit)"
    else
      puts 'Další krok: není co commitovat.'
    end
  when :commit
    files = repo.commit_and_push
    abort 'Není co commitovat. Další krok: --gen.' if files.empty?
    puts 'Pushnuto, na webu je:'
    files.grep(/\.wiki\z/).each { |f| puts "  https://pikomat.mff.cuni.cz/#{f.delete_suffix('.wiki')}" }
    puts
    puts 'Další krok: zkontrolovat stránky na webu; u nové série oznámení do novinek a rámečků.'
  when :clean
    repo.clean
    puts "Klon #{opt[:web]} je stejný jako web na serveru. Další krok: #{me} --gen."
  else
    case ARGV[0]
    when 'check'
      sync.call.check(Integer(ARGV.fetch(1)))
    when 'diff'
      sync.call.diff(Integer(ARGV.fetch(1)), ARGV.fetch(2), junior: opt[:junior])
    when nil
      abort parser.banner
    else
      file = ARGV[0]
      rocnik = opt[:rocnik] || file[%r{(?:^|/)(\d\d)(?:_|/)}, 1]&.to_i
      wiki, c = Tex2Wiki.page(File.read(file), rocnik: rocnik, junior: opt[:junior], source: file)
      puts wiki
      c.warnings.each { |w| $stderr.puts "varování: #{w}" }
    end
  end
end
