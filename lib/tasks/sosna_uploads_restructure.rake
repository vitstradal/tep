##
# Konverze a úklid var/uploads/ — cíl: v kořeni jen adresáře.
#
# Fáze (všechny idempotentní, task lze pouštět opakovaně):
#  1. oprava sirotků: řešení, jejichž problem_id ukazuje na smazanou úlohu;
#     roc/level/se/ul se přečtou ze jména souboru a najde se znovuzaložená
#     úloha. Podle stavu: repoint (řešitel u nové úlohy nic nemá),
#     adopt (nový řádek bez souboru zdědí soubor, sirotek se smaže),
#     dup (nový řádek soubor má, sirotek se smaže).
#  2. přesun souborů z plochého kořene do rocnikNN[-jr]/serieMM/
#     a úprava cest v DB (filename/filename_corr relativně k uploads).
#     Přesouvá i .tmpl sidecary (záloha pdf před vepsáním hlavičky).
#  3. přesun návratek confirm-file-*.pdf z kořene do navratky/
#     (aplikace je tam nově i ukládá, viz _confirm_file_path)
#  4. jen s CLEAN=1: smazání nereferencovaných souborů v kořeni starších
#     30 dní (mrtvá řešení po smazání/přejmenování, .bad, staré zipy).
#
#   rake sosna:uploads_restructure DRY=1 [CLEAN=1]  # jen vypíše, co by udělal
#   rake sosna:uploads_restructure [CLEAN=1]
namespace :sosna do
  desc 'Uklid uploads: oprava sirotku, presun do rocnikNN[-jr]/serieMM/, s CLEAN=1 smazani mrtvych (DRY=1 nic nemeni)'
  task uploads_restructure: :environment do
    dry = ENV['DRY'] == '1'
    clean = ENV['CLEAN'] == '1'
    base = Sosna::SolutionController::UPLOAD_DIR
    stats = Hash.new(0)

    ## --- 1) oprava sirotku (problem_id na smazanou ulohu) -----------------
    Sosna::Solution
      .where('filename IS NOT NULL OR filename_corr IS NOT NULL')
      .where.not(problem_id: Sosna::Problem.select(:id)).each do |sol|
      fname = sol.filename || sol.filename_corr
      m = %r{^(?:.*/)?reseni-roc(\d+)([a-z]*)-se(\d+)-ul(\d+)-rel(\d+)-}.match(fname)
      if m.nil?
        puts "sirotek #{sol.id}: nectitelne jmeno '#{fname}', nechavam"
        stats[:bad] += 1
        next
      end
      annual, level = m[1].to_i, Sosna::Solver.level_from_short(m[2])
      round, ul = m[3].to_i, m[4].to_i
      problem = Sosna::Problem.where(annual: annual, level: level,
                                     round: round, problem_no: ul).take
      if problem.nil?
        puts "sirotek #{sol.id}: uloha roc#{annual}#{m[2]} se#{round} ul#{ul} neexistuje, nechavam"
        stats[:bad] += 1
        next
      end
      twin = Sosna::Solution.where(problem_id: problem.id, solver_id: sol.solver_id)
                            .where.not(id: sol.id).take
      if twin.nil?
        puts "sirotek #{sol.id}: repoint -> problem #{problem.id}"
        sol.update_columns(problem_id: problem.id) unless dry
        stats[:repoint] += 1
      elsif twin.filename.nil?
        puts "sirotek #{sol.id}: soubor prebira sol #{twin.id} (#{sol.filename})"
        unless dry
          twin.update_columns(filename: sol.filename, filename_orig: sol.filename_orig,
                              filename_corr: sol.filename_corr,
                              filename_corr_display: sol.filename_corr_display)
          sol.delete
        end
        stats[:adopt] += 1
      else
        puts "sirotek #{sol.id}: duplikat (soubor patri sol #{twin.id}), mazu radek"
        sol.delete unless dry
        stats[:dup] += 1
      end
    end

    ## --- 2) presun referencovanych souboru do podadresaru -----------------
    Sosna::Solution
      .where('filename IS NOT NULL OR filename_corr IS NOT NULL')
      .includes(:problem).find_each do |sol|
      if sol.problem.nil?
        # sirotek, ktereho faze 1 neumela opravit (pri DRY=1 vsichni)
        stats[:bad_move] += 1
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

    ## --- 3) presun navratek z korene do navratky/ --------------------------
    Dir.glob(base + 'confirm-file-*.pdf').sort.each do |src|
      f = File.basename(src)
      puts "navratka: #{f} -> navratky/#{f}"
      unless dry
        FileUtils.mkdir_p base + 'navratky'
        FileUtils.mv src, base + 'navratky/' + f
      end
      stats[:confirm] += 1
    end

    ## --- 4) CLEAN=1: smazani mrtvych souboru v koreni ---------------------
    if clean
      refs = Set.new
      Sosna::Solution.where('filename IS NOT NULL OR filename_corr IS NOT NULL')
                     .pluck(:filename, :filename_corr).each do |f, fc|
        refs << f if f
        refs << fc if fc
      end
      cutoff = Time.now - 30 * 24 * 3600
      Dir.children(base).sort.each do |f|
        path = base + f
        next if File.directory?(path)
        next if f =~ /^confirm-file-\d+\.pdf$/                    # navratky patri do korene
        if refs.include?(f) || (f.end_with?('.tmpl') && refs.include?(f.delete_suffix('.tmpl')))
          stats[:keep_ref] += 1
        elsif File.mtime(path) < cutoff
          puts "mazu (nereferencovane, #{(Time.now - File.mtime(path)).to_i / 86400} dni): #{f}"
          File.delete(path) unless dry
          stats[:deleted] += 1
        else
          puts "nechavam (mladsi nez 30 dni): #{f}"
          stats[:keep_young] += 1
        end
      end
    end

    puts "sosna:uploads_restructure#{dry ? ' [DRY RUN]' : ''}: " \
         "sirotci: repoint #{stats[:repoint]}, adopt #{stats[:adopt]}, dup #{stats[:dup]}, " \
         "vadných #{stats[:bad]}; " \
         "přesunuto #{stats[:moved]}, jen-db #{stats[:dbonly]}, " \
         "už převedeno #{stats[:already]}, chybí #{stats[:missing]}, " \
         "navratek #{stats[:confirm]}" +
         (clean ? "; smazáno #{stats[:deleted]}, mladých #{stats[:keep_young]}" : '')
  end
end
