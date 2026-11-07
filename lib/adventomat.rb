##
# Ročník adventomatu: zadání, výsledky a nastavení ze stránky piki
# `adventomat/<rok>/index.wiki` (viz docs/superpowers/specs/2026-11-07-adventomat-design.md).
class Adventomat
  WIKI = 'piki'
  BONUS = 25
  ZONE = ActiveSupport::TimeZone['Europe/Prague']
  HEADER = { 'název' => :title, 'otevírání' => :opening, 'uzávěrka' => :closing,
             'v tabulce od' => :min_table, 'pořadí' => :order }.freeze

  Day = Struct.new(:no, :text, :result_raw, :note, :images, keyword_init: true) do
    def label
      no == BONUS ? 'bonus' : no.to_s
    end

    def result
      raw = result_raw.to_s.gsub(/\s+/, '')
      raw.match?(/\A-?\d+\z/) ? raw.to_i : nil
    end
  end

  attr_reader :year, :days, :reward, :header, :header_errors

  def self.quiz_name(year)
    "advent-#{year}"
  end

  def self.year_of(name)
    name.to_s[/\Aadvent-(\d{4})\z/, 1]&.to_i
  end

  def self.page_path(year)
    "adventomat/#{year}/index.wiki"
  end

  def self.load(year)
    giwi = Giwi.get_giwi(WIKI)
    return nil if giwi.nil? || year.to_i < 2000
    text, = giwi.get_page(page_path(year))
    return nil if text.nil?
    files, = giwi.get_ls("adventomat/#{year}")
    new(year.to_i, text, files: files.to_a.map { |f| f[:name] }, giwi: giwi)
  rescue StandardError => e
    Rails.logger.warn("adventomat #{year}: #{e.message}")
    nil
  end

  def self.parse(year, text, files: nil)
    new(year, text, files: files)
  end

  def initialize(year, text, files: nil, giwi: nil)
    @year = year
    @files = files
    @giwi = giwi
    @header = {}
    @header_errors = []
    @days = {}
    _parse(text.to_s)
  end

  def quiz_name
    self.class.quiz_name(@year)
  end

  def title
    @header[:title].presence || "Adventomat #{@year}"
  end

  def min_table
    (@header[:min_table].presence || 4).to_i
  end

  def open_at(no)
    h, m = _opening
    ZONE.local(@year, 12, no == BONUS ? 24 : no, h, m)
  end

  def open?(no, now = Time.current)
    (1..BONUS).cover?(no) && now >= open_at(no)
  end

  def next_open_at(now = Time.current)
    (1..24).map { |n| open_at(n) }.find { |t| t > now }
  end

  def closes_at
    _closing || ZONE.local(@year, 12, 26, 23, 59)
  end

  # pořadí okének v mřížce: z hlavičky, jinak zamíchané stabilně podle roku
  def order
    all = (1..24).to_a + (@days[BONUS] ? [BONUS] : [])
    listed = @header[:order].to_s.split(/[,;\s]+/).filter_map { |l| _label_no(l) }.uniq & all
    return listed + (all - listed) if listed.any?
    all.shuffle(random: Random.new(@year))
  end

  def check_answer(no, raw)
    answer = raw.to_s.gsub(/\s+/, '')
    return :not_number unless answer.match?(/\A-?\d+\z/)
    result = @days[no]&.result
    !result.nil? && answer.to_i == result
  end

  def day_html(no)
    day = @days[no]
    day && render(day.text)
  end

  def reward_html
    @reward && render(@reward)
  end

  def reward_images
    @reward ? _images(@reward) : []
  end

  # obrázek smí ven, když ho zobrazuje některý z dnů v open_days nebo odměna při reward
  def image_allowed?(name, open_days, reward: false)
    open_days.any? { |n| @days[n]&.images&.include?(name) } || (reward && reward_images.include?(name))
  end

  def image(name)
    return nil if @giwi.nil? || name.to_s.include?('..')
    @giwi.get_blob("adventomat/#{@year}/#{name}")
  end

  def render(text)
    html = text.gsub(/Image\(\s*([^,)\s]+)/) { "Image(#{_image_url(Regexp.last_match(1))}" }
    TracWiki.parser(base: '/', root: '/', math: true, allow_html: true, no_escape: true,
                    allowed_schemes: %w[http https mailto]).to_html(html)
  end

  def issues
    list = @header_errors.map { |t| { day: nil, level: :error, text: t } }
    (1..BONUS).each do |n|
      day = @days[n]
      if day.nil?
        list << { day: n, level: :error, text: 'den chybí' } unless n == BONUS
        next
      end
      if day.result_raw.to_s.strip.empty?
        list << { day: n, level: :error, text: 'chybí výsledek' }
      elsif day.result.nil?
        list << { day: n, level: :error, text: 'výsledek není celé číslo' }
      end
      list << { day: n, level: :warn, text: 'prázdné zadání' } if day.text.strip.empty?
      _missing_images(day.images).each { |f| list << { day: n, level: :error, text: "obrázek #{f} v piki není" } }
    end
    _missing_images(reward_images).each { |f| list << { day: :reward, level: :error, text: "obrázek #{f} v piki není" } }
    list
  end

  private

  def _parse(text)
    section = nil
    lines = []
    flush = lambda do
      _section(section, lines) if section
      lines = []
    end
    text.each_line do |line|
      if (m = line.match(/\A==\s*([^=]+?)\s*==\s*\z/))
        flush.call
        section = m[1].strip.downcase
      elsif section.nil?
        k, v = line.split(':', 2)
        key = HEADER[k.to_s.strip.downcase]
        @header[key] = v.to_s.strip if key && v
      else
        lines << line
      end
    end
    flush.call
    _opening
    _closing
  end

  def _section(name, lines)
    if name == 'odměna'
      @reward = lines.join.strip
      return
    end
    no = _label_no(name)
    return unless no
    result = note = nil
    body = lines.reject do |l|
      if (m = l.match(/\A\s*výsledek\s*:(.*)$/i)) then result = m[1].strip
      elsif (m = l.match(/\A\s*poznámka\s*:(.*)$/i)) then note = m[1].strip
      end
    end.join.strip
    @days[no] = Day.new(no: no, text: body, result_raw: result, note: note, images: _images(body))
  end

  def _label_no(label)
    label = label.to_s.strip.downcase.delete_suffix('.')
    return BONUS if label == 'bonus'
    n = label.match?(/\A\d+\z/) ? label.to_i : nil
    n if n && (1..24).cover?(n)
  end

  def _images(text)
    text.scan(/Image\(\s*([^,)\s]+)/).flatten.filter_map { |src| _image_name(src) }.uniq
  end

  def _image_name(src)
    return nil if src.match?(%r{\A[a-z]+://})
    src.sub(%r{\A/?(piki/)?adventomat/#{@year}/}, '').delete_prefix('/')
  end

  def _image_url(src)
    name = _image_name(src)
    name ? "/quiz/#{quiz_name}/obrazek/#{name}" : src
  end

  def _missing_images(names)
    return [] if @files.nil?
    names - @files
  end

  def _opening
    raw = @header[:opening].presence || '3:14'
    m = raw.match(/\A(\d{1,2}):(\d{2})\z/)
    return [m[1].to_i, m[2].to_i] if m
    _header_error("otevírání „#{raw}“ není čas (např. 3:14)")
    [3, 14]
  end

  def _closing
    raw = @header[:closing]
    return nil if raw.blank?
    m = raw.match(/\A(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})?\s+(\d{1,2}):(\d{2})\z/)
    return ZONE.local((m[3] || @year).to_i, m[2].to_i, m[1].to_i, m[4].to_i, m[5].to_i) if m
    _header_error("uzávěrka „#{raw}“ není datum a čas (např. 26. 12. 23:59)")
    nil
  end

  def _header_error(text)
    @header_errors << text unless @header_errors.include?(text)
  end
end
