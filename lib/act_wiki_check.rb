require 'did_you_mean'

##
# Kontrola wiki stránek akcí (info, piki, fotky): stránka existuje, má {{akce}}
# a záložky na ní ukážou správnou akci; k nálezům píše poznámky.
class ActWikiCheck
  FIELDS = { info: :event_info_url, piki: :event_piki_url, foto: :event_photos_url }.freeze
  HOST = %r{\Ahttps?://pikomat\.mff\.cuni\.cz(?=/|\z)}
  MACRO = /\{\{akce(\}\}|\s|\|)/
  AUTHOR = 'tep act:wiki_check <pikomat@mff.cuni.cz>'
  STATUS = { ok: 'v pořádku', no_macro: 'chybí {{akce}}', missing: 'stránka neexistuje', external: 'mimo web pikomatu',
             no_wiki: 'neznámá wiki', none: 'bez info stránky' }.freeze

  Item = Struct.new(:event, :kind, :url, :wiki, :page, :status, :shared, :notes, :level, keyword_init: true) do
    def problem?
      %i[warn error].include?(level)
    end
  end

  # cesta stránky bez hostu a kotvy, nil pro externí odkaz
  def self.local_path(url)
    path = request_path(url)
    path && (path.sub(%r{/+\z}, '').presence || '/')
  end

  # adresa, na kterou prohlížeč po kliknutí na odkaz přijde (bez hostu, kotvy a parametrů)
  def self.request_path(url)
    url = url.to_s.strip.sub(HOST, '')
    return nil unless url.start_with?('/')
    url.sub(/[#?].*\z/, '').presence || '/'
  end

  def initialize(events = Act::Event.all)
    @events = events
  end

  def items
    list = @events.flat_map do |ev|
      FIELDS.filter_map do |kind, field|
        url = ev.send(field).to_s.strip
        next _no_info(ev) if url.empty? && kind == :info
        next if url.empty?
        _item(ev, kind, url)
      end
    end
    counts = list.group_by { |i| [i.kind, self.class.local_path(i.url)] }.transform_values(&:size)
    list.each do |i|
      path = self.class.local_path(i.url)
      i.shared = !path.nil? && counts[[i.kind, path]] > 1
      _shown_event_note(i)
      i.level ||= i.notes.empty? ? :ok : :info
    end
    list
  end

  # doplní {{akce}} na začátek stránek bez něj; vrací opravené položky
  def fix!(list = items, author = AUTHOR)
    done = {}
    list.select { |i| i.status == :no_macro }.each do |i|
      key = [i.wiki.name, i.page]
      next if done[key]
      text, oid = i.wiki.get_page(i.page)
      next if text.nil? || text =~ MACRO
      i.wiki.set_page(i.page, "{{akce}}\n#{text}", oid.to_s, author)
      done[key] = i
    end
    Rails.cache.clear if done.any? && Rails.configuration.try(:wiki_do_cache_parse)
    done.values
  end

  private

  def _no_info(ev)
    note = ev.body.present? ? 'záložka Informace ukáže stručný popis akce' : 'akce nemá info stránku ani stručný popis'
    Item.new(event: ev, kind: :info, url: '', status: :none, notes: [note], level: :info)
  end

  def _item(ev, kind, url)
    item = Item.new(event: ev, kind: kind, url: url, notes: [])
    path = self.class.local_path(url)
    if path.nil?
      item.status = :external
      if kind == :foto
        item.level = :ok
      else
        item.notes << 'odkaz mimo web pikomatu, záložky akce tam nebudou'
        item.level = :warn
      end
      return item
    end
    item.notes << 'odkaz začíná http://, lepší je https://' if url.start_with?('http://')
    wiki, rel = _wiki_for(path)
    item.wiki = wiki
    if wiki.nil?
      item.status = :no_wiki
      item.level = :error
      return item
    end
    _wiki_notes(item, wiki, rel)
    item.page = _page_file(wiki, rel)
    if item.page.nil?
      item.status = :missing
      item.level = :error
      hint = _similar_page(wiki, rel)
      item.notes << (hint ? "možná jsi myslel #{hint}" : "stránka #{path} ve wiki #{wiki.name} není")
      return item
    end
    text, = wiki.get_page(item.page)
    item.status = text.to_s =~ MACRO ? :ok : :no_macro
    if item.status == :no_macro
      item.notes << 'na stránce chybí {{akce}}, záložky akce se nezobrazí (opraví tlačítko)'
      item.level = :warn
    end
    req = self.class.request_path(url)
    if req.length > 1 && req.end_with?('/')
      item.notes << "odkaz končí lomítkem; na #{req.chomp('/')} bez lomítka se záložky neukážou"
    end
    item.notes << 'odkaz má ?parametry, záložky se podle něj nenajdou' if url.include?('?')
    item
  end

  # na stránce s {{akce}} se ukážou záložky té akce, kterou najde layout podle adresy
  def _shown_event_note(item)
    return unless %i[ok no_macro].include?(item.status)
    shown, = Act::Event.for_wiki_path(self.class.request_path(item.url))
    if shown.nil?
      item.notes << 'záložky k téhle adrese žádnou akci nenajdou'
      item.level = :warn
    elsif shown.id != item.event.id
      item.notes << "stránku sdílí víc akcí, záložky ukážou „#{shown.title}“ (##{shown.id})"
      item.level = :warn
    end
  end

  def _wiki_notes(item, wiki, rel)
    main = Giwi.get_giwi('main')
    if main && wiki.name.to_s != 'main' && wiki.path == main.path
      item.notes << "odkaz vede do editace webu (/#{wiki.url}), patří tam /#{rel}"
      item.level = :warn
    elsif item.kind == :info && wiki.read.to_s != 'anon'
      item.notes << "info stránka je ve wiki #{wiki.name}, kterou účastníci nevidí"
      item.level = :warn
    elsif item.kind == :piki && wiki.name.to_s == 'main'
      item.notes << 'piki odkaz vede na veřejný web'
    end
  end

  def _wiki_for(path)
    Giwi.giwis.each_value do |g|
      next if g.name.to_s == 'main' || g.url.to_s.empty?
      prefix = "/#{g.url}"
      return [g, path.delete_prefix(prefix).delete_prefix('/')] if path == prefix || path.start_with?("#{prefix}/")
    end
    [Giwi.get_giwi('main'), path.delete_prefix('/')]
  end

  def _page_file(wiki, rel)
    rel = 'index' if rel.empty?
    cands = ["#{rel}#{wiki.ext}", "#{rel}/index#{wiki.ext}"]
    cands.find { |c| wiki.file?(c) }
  end

  # podobně pojmenovaná stránka ve stejném adresáři (překlep, velikost písmen)
  def _similar_page(wiki, rel)
    dir, _, name = rel.rpartition('/')
    return nil if name.empty?
    return nil unless dir.empty? || wiki.dir?(dir)
    files, dirs, = wiki.get_ls(dir.dup)
    names = files.map { |f| f[:name].delete_suffix(wiki.ext.to_s) } + dirs.map { |d| d[:name] }
    names -= ['..']
    hit = names.find { |n| n.casecmp?(name) } || DidYouMean::SpellChecker.new(dictionary: names).correct(name).first
    hit && "/#{wiki.url.to_s.empty? ? '' : "#{wiki.url}/"}#{dir.empty? ? '' : "#{dir}/"}#{hit}"
  rescue StandardError
    nil
  end
end
