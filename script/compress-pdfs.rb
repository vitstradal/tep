#!/usr/bin/env ruby
##
# compress-pdfs.rb — komprese PDF řešení uzavřeného ročníku (ori i rev).
#
# Čistý Ruby + Zlib, ŽÁDNÉ Rails (rake tu nejde použít: config/application.rb
# spouští Giwi.setup při každém načtení Rakefile a pod rootem/vitas padá na
# právech k wiki). Tep komprimovaná PDF čte transparentně —
# viz Sosna::Solution.real_path a _send_pdf v solution controlleru.
#
# Použití:
#   ruby script/compress-pdfs.rb 40 [uploads_dir]      # default var/uploads/
#   make prod-compress-pdfs ROC=40
#
# Gzipne každé *.pdf v rocnikNN*/ do <soubor>.pdf.gz a originál smaže —
# ale jen když komprese ušetří aspoň 5 % (PDF mají vnitřní kompresi);
# jinak .gz zahodí a nechá originál. Opakované spuštění je neškodné.

require 'zlib'

rocnik = ARGV[0].to_s
abort 'pouziti: ruby script/compress-pdfs.rb <rocnik> [uploads_dir]' if rocnik.empty?
upload_dir = ARGV[1] || 'var/uploads/'
abort "adresar #{upload_dir} neexistuje (spust z korene tepu, nebo dej cestu)" unless Dir.exist?(upload_dir)

dirs = Dir.glob(File.join(upload_dir, format('rocnik%02i*', rocnik.to_i)))
abort format("zadny adresar rocnik%02i* v #{upload_dir}", rocnik.to_i) if dirs.empty?

zkomprimovano = preskoceno = usetreno = 0
dirs.each do |d|
  Dir.glob(File.join(d, '**', '*.pdf')).sort.each do |pdf|
    gz = "#{pdf}.gz"
    next if File.exist?(gz)
    data = File.binread(pdf)
    Zlib::GzipWriter.open(gz, 9) { |g| g.write data }
    if File.size(gz) < data.bytesize * 95 / 100
      File.delete(pdf)
      zkomprimovano += 1
      usetreno += data.bytesize - File.size(gz)
    else
      File.delete(gz)
      preskoceno += 1
    end
  end
end

puts "compress-pdfs rocnik #{rocnik}: zkomprimovano #{zkomprimovano}, " \
     "ponechano (uspora < 5 %) #{preskoceno}, usetreno #{usetreno / 1024 / 1024} MB"
