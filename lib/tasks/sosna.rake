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

end
