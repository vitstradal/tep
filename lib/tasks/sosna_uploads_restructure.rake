##
# Jednorázová konverze: přesune soubory řešení z plochého var/uploads/
# do struktury var/uploads/rocnikNN[-jr]/serieMM/ a upraví cesty v DB
# (sloupce filename a filename_corr drží cestu relativní k uploads).
#
# Idempotentní — už převedené řádky (obsahují '/') přeskakuje.
# Přesouvá i .tmpl sidecary (záloha pdf před vepsáním hlavičky).
#
#   rake sosna:uploads_restructure DRY=1   # jen vypíše, co by udělal
#   rake sosna:uploads_restructure
namespace :sosna do
  desc 'Presune reseni do var/uploads/rocnikNN[-jr]/serieMM/ a upravi cesty v DB (DRY=1 nic nemeni)'
  task uploads_restructure: :environment do
    dry = ENV['DRY'] == '1'
    base = Sosna::SolutionController::UPLOAD_DIR
    stats = Hash.new(0)

    Sosna::Solution
      .where('filename IS NOT NULL OR filename_corr IS NOT NULL')
      .includes(:problem).find_each do |sol|
      if sol.problem.nil?
        puts "solution #{sol.id}: nemá problem, přeskakuji"
        stats[:bad] += 1
        next
      end
      [:filename, :filename_corr].each do |col|
        val = sol[col]
        next if val.nil? || val.empty?
        if val.include?('/')
          stats[:already] += 1
          next
        end
        target = File.join(sol.subdir, val)
        src, dst = base + val, base + target
        if File.exist?(src)
          unless dry
            FileUtils.mkdir_p File.dirname(dst)
            FileUtils.mv src, dst
            FileUtils.mv src + '.tmpl', dst + '.tmpl' if File.exist?(src + '.tmpl')
            sol.update_column(col, target)
          end
          puts "solution #{sol.id}: #{val} -> #{target}"
          stats[:moved] += 1
        elsif File.exist?(dst)
          # soubor už někdo přesunul, dorovnáme jen DB
          sol.update_column(col, target) unless dry
          puts "solution #{sol.id}: soubor už na místě, jen DB -> #{target}"
          stats[:dbonly] += 1
        else
          puts "solution #{sol.id}: CHYBÍ soubor #{src}, nechávám beze změny"
          stats[:missing] += 1
        end
      end
    end

    puts "sosna:uploads_restructure#{dry ? ' [DRY RUN]' : ''}: " \
         "přesunuto #{stats[:moved]}, jen-db #{stats[:dbonly]}, " \
         "už převedeno #{stats[:already]}, chybí #{stats[:missing]}, vadných #{stats[:bad]}"
  end
end
