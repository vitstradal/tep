##
# Kontrola wiki stránek akcí (info, piki, fotky): stránka existuje a má {{akce}},
# aby na ní byly záložky akce.
class ActWikiCheck
  FIELDS = { info: :event_info_url, piki: :event_piki_url, foto: :event_photos_url }.freeze
  HOST = %r{\Ahttps?://pikomat\.mff\.cuni\.cz(?=/|\z)}
  MACRO = /\{\{akce(\}\}|\s|\|)/
  AUTHOR = 'tep act:wiki_check <pikomat@mff.cuni.cz>'

  Item = Struct.new(:event, :kind, :url, :wiki, :page, :status, :shared, keyword_init: true)

  # cesta stránky bez hostu a kotvy, nil pro externí odkaz
  def self.local_path(url)
    url = url.to_s.strip.sub(HOST, '')
    return nil unless url.start_with?('/')
    url.sub(/[#?].*\z/, '').sub(%r{/+\z}, '').presence || '/'
  end

  def initialize(events = Act::Event.all)
    @events = events
  end

  def items
    list = @events.flat_map do |ev|
      FIELDS.filter_map do |kind, field|
        url = ev.send(field).to_s.strip
        next if url.empty?
        _item(ev, kind, url)
      end
    end
    counts = list.group_by { |i| [i.kind, self.class.local_path(i.url)] }.transform_values(&:size)
    list.each { |i| i.shared = counts[[i.kind, self.class.local_path(i.url)]].to_i > 1 if self.class.local_path(i.url) }
    list
  end

  # doplní {{akce}} na začátek stránek bez něj; vrací opravené položky
  def fix!(list = items)
    done = {}
    list.select { |i| i.status == :no_macro }.each do |i|
      key = [i.wiki.name, i.page]
      next if done[key]
      text, oid = i.wiki.get_page(i.page)
      next if text.nil? || text =~ MACRO
      i.wiki.set_page(i.page, "{{akce}}\n#{text}", oid.to_s, AUTHOR)
      done[key] = i
    end
    Rails.cache.clear if done.any? && Rails.configuration.try(:wiki_do_cache_parse)
    done.values
  end

  private

  def _item(ev, kind, url)
    item = Item.new(event: ev, kind: kind, url: url)
    path = self.class.local_path(url)
    return item.tap { |i| i.status = :external } if path.nil?
    wiki, rel = _wiki_for(path)
    item.wiki = wiki
    return item.tap { |i| i.status = :no_wiki } if wiki.nil?
    item.page = _page_file(wiki, rel)
    return item.tap { |i| i.status = :missing } if item.page.nil?
    text, = wiki.get_page(item.page)
    item.status = text.to_s =~ MACRO ? :ok : :no_macro
    item
  end

  def _wiki_for(path)
    Giwi.giwis.each_value do |g|
      next if g.name.to_s == 'main' || g.url.to_s.empty?
      prefix = "/#{g.url}"
      return [g, path.delete_prefix(prefix).delete_prefix('/')] if path == prefix || path.start_with?("#{prefix}/")
    end
    main = Giwi.get_giwi('main')
    [main, path.delete_prefix('/')]
  end

  def _page_file(wiki, rel)
    rel = 'index' if rel.empty?
    cands = ["#{rel}#{wiki.ext}", "#{rel}/index#{wiki.ext}"]
    cands.find { |c| wiki.file?(c) }
  end
end
