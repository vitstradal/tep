#!/usr/bin/env ruby
# Převod starého adventomatu (makra ve web/adventomat/<rok>/index.wiki) do piki adventomat/<rok>/index.wiki.
# Použití: ruby script/adventomat_import.rb ~/git/web ~/git/piki 2025 [2024 …]; commit a push dělá org.
require 'fileutils'

MACRO = /\A\{\{adventomat\s+\w+\|(.*)\}\}\s*\z/

def day_label(date)
  date = date.strip
  return 'bonus' if date.downcase == 'bonus'
  date[/\A(\d+)\./, 1] or abort "neznámé datum okénka: #{date}"
end

def import(web, piki, year)
  page = File.join(web, 'adventomat', year, 'index.wiki')
  lines = File.readlines(page)
  out_dir = File.join(piki, 'adventomat', year)
  FileUtils.mkdir_p(out_dir)

  days = lines.filter_map do |l|
    m = l.match(MACRO) or next
    date, text, result, img = m[1].split('|', 4).map(&:strip)
    text = text.gsub('[', '![')
    label = day_label(date)
    if img.to_s != ''
      src = File.join(web, img.delete_prefix('/'))
      abort "obrázek #{src} neexistuje" unless File.exist?(src)
      name = File.basename(img)
      FileUtils.cp(src, File.join(out_dir, name))
      text = "#{text}\n[[Image(#{name})]]"
    end
    [label, text, result]
  end
  abort "#{page}: žádná okénka" if days.empty?

  reward = nil
  marvin = File.join(web, 'adventomat', year, 'marvin.wiki')
  if File.exist?(marvin)
    FileUtils.cp(File.join(web, 'adventomat', year, 'marvin.png'), File.join(out_dir, 'marvin.png'))
    reward = File.read(marvin).sub(/\A=[^\n]*=\s*\n/, '').gsub(%r{Image\(/adventomat/#{year}/marvin\.png}, 'Image(marvin.png').strip
  end

  wiki = +"= Adventomat #{year} =\n\nPřevedeno ze staré stránky web/adventomat/#{year}; veřejná stránka je /adventomat/#{year}.\n\n"
  wiki << "název: Adventomat #{year}\n"
  wiki << "pořadí: #{days.map(&:first).join(', ')}\n"
  days.sort_by { |label, *| label == 'bonus' ? 99 : label.to_i }.each do |label, text, result|
    wiki << "\n== #{label} ==\n#{text}\nvýsledek: #{result}\n"
  end
  wiki << "\n== odměna ==\n#{reward}\n" if reward
  File.write(File.join(out_dir, 'index.wiki'), wiki)

  # webová stránka: makra → {{adventomat_kalendar}}, starý modál s informem pryč
  web_out = []
  skip_modal = false
  placed = false
  lines.each do |l|
    if l.start_with?("<div id='adventomat-modal'")
      skip_modal = true
    elsif skip_modal
      skip_modal = false if l.include?('</div></div></div></div>')
    elsif l.match?(MACRO)
      web_out << "{{adventomat_kalendar #{year}}}\n" unless placed
      placed = true
    elsif !l.start_with?('{{!set adventomat_year')
      web_out << l
    end
  end
  File.write(page, web_out.join.rstrip + "\n")
  puts "#{year}: #{days.size} okének, odměna: #{reward ? 'ano' : 'ne'}"
end

web, piki, *years = ARGV
abort 'použití: adventomat_import.rb WEB_DIR PIKI_DIR ROK…' if years.empty?
years.each { |y| import(File.expand_path(web), File.expand_path(piki), y) }
