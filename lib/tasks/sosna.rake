##
# Údržbové tasky řešitelů.
namespace :sosna do
  desc 'Doplň paper_jr/paper_pi stávajícím papírovým řešitelům (zachová dnešní stav: všem senior, juniorům do 6. ročníku i junior)'
  task backfill_paper_levels: :environment do
    papiroví = Sosna::Solver.where(where_to_send: ['home', 'school'])
    count = 0
    papiroví.find_each do |s|
      next if s.paper_jr || s.paper_pi   # už nastaveno, nesahat
      s.update_columns(paper_pi: true, paper_jr: s.junior?)
      count += 1
    end
    puts "sosna:backfill_paper_levels: doplněno #{count} řešitelů"
  end

  desc 'Zkomprimuj PDF řešení uzavřeného ročníku (gzip; tep je čte transparentně). Např: rake "sosna:compress_pdfs[40]"'
  task :compress_pdfs, [:rocnik] => :environment do |_, args|
    abort 'zadej ročník: rake "sosna:compress_pdfs[40]"' if args[:rocnik].to_s.empty?
    upload_dir = Sosna::SolutionController::UPLOAD_DIR
    dirs = Dir.glob(File.join(upload_dir, format('rocnik%02i*', args[:rocnik].to_i)))
    abort "žádný adresář rocnik%02i* v #{upload_dir}" % args[:rocnik].to_i if dirs.empty?

    zkomprimovano = preskoceno = 0
    usetreno = 0
    dirs.each do |d|
      Dir.glob(File.join(d, '**', '*.pdf')).sort.each do |pdf|
        gz = "#{pdf}.gz"
        next if File.exist?(gz)
        data = File.binread(pdf)
        Zlib::GzipWriter.open(gz, 9) { |g| g.write data }
        # PDF má vnitřní kompresi — gzip se vyplatí jen někdy; drž menší
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
    puts "sosna:compress_pdfs[#{args[:rocnik]}]: zkomprimováno #{zkomprimovano}, " \
         "ponecháno (úspora < 5 %) #{preskoceno}, ušetřeno #{usetreno / 1024 / 1024} MB"
  end
end
