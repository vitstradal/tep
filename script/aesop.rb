
require 'date'

# version   Verze formátu. Tato specifikace popisuje verzi 1.
# event   Identifikátor akce (např. ksp.rocnik.z)
# year    Rok, v němž se akce konala. Je-li akce spjata se školním rokem, patří sem první rok.
# date  Datum vytvoření exportu ve tvaru YYYY-MM-DD HH:MM:SS.
# errors-to   E-mailová adresa, na níž se mají odesílat zprávy o chybách při zpracování exportu.
# max-rank  Počet účastníků (povinné, pokud se část účastníků z nějakého důvodu neexportuje).
# max-points  Maximální možný počet získaných bodů. 



# name    Křestní jméno. Může jich být více, oddělených mezerou.
# surname   Příjmení.
# street  Korespondenční adresa: ulice a domovní číslo. Pokud se jedná o obec bez ulic, pište prosím jen domovní číslo, případně název obce a domovní číslo.
# postcode  Korespondenční adresa: směrovací číslo. U českých a slovenských adres 5 číslic bez mezery.
# country   Korespondenční adresa: kód státu podle ISO 3166-1 (cz, sk, apod.). Na velikosti písmen nezáleží.
# fullname  Pokud se v adrese má na pozici jména vyskytnout něco jiného než
#            Jméno Příjmení, vložte to sem. To se dá použít, pokud chcete hezky formátovat
#            např. cizí jména, u nichž je zvykem uvádět příjmení jako první. Rozhodně se
#            cizí pořadí nepokoušejte simulovat prohozením položek name a surname.
#
# school      Identifikátor školy. Zatím jsou definované formáty „izo:XYZ“ (české
#             IZO), „sk:XYZ“ (slovenský kód školy), „aesop:XYZ“ (interní ID v AESOPovi),
#             „ufo“ (škola, kterou zatím neumíme identifikovat; takové záznamy by se měly
#             vyskytovat jen po velmi krátkou dobu).
# end-year    Rok očekávaného konce středoškolského studia.
# email       E-mailová adresa podle RFC 5322.
# rank        Pořadí ve výsledkovce. Pokud se více účastníků dělí o místo, patří sem nejmenší ze sdílených pořadí.
# points      Počet získaných bodů.
# spam-flag   „Y“ pokud účastník svolil k zasílání materiálů Matfyzu, „N“ pokud jsme se ho ptali a nesvolil. Prázdný řetězec znamená, že jsme se explicitně nezeptali.
# spam-date   Datum (YYYY-DD-MM), kdy jsme se dozvěděli hodnotu spam-flag-u. 

def print_round(annual, round)

  errors_to = 'vitas@pikomat.mff.cuni.cz'

  maturity_grade = 13
  date = DateTime.now.strftime('%Y-%m-%d %H:%M:%S')
  year = 2014 + annual - 30
  event = "pikomat.#{annual}"
  event = "pikomat.rocnik"
  comment = "Pikomat rocnik=#{annual} serie=#{round}"

  solvers = Sosna::Solver.where(annual: annual, is_test_solver: false) 
  ex = []
  ex << ['version',     1]
  ex << ['year',        year]
  ex << ['event',       event]
  ex << ['errors-to',    errors_to]
  ex << ['date',        date]
  ex << ['max-rank',   solvers.count ]
  ex << ['max-points',  round * 30]
  ex << ['comment',  comment ]
  ex << []
  ex << ['id', 'name', 'surname', 'fullname', 'school', 'street', 'postcode', 'town', 'country', 'email', 'end-year', 'rank', 'points', 'spam-flag', 'spam-date',
         #'grade',
         ]
  
  solvers.each  do |solver|
  
  
    next if ['p.zahajska@yahoo.com', 'lux.filip@gmail.com'  ] .include? solver.email
    school = solver.school

    rank = 0
    points = 0
  
    res = Sosna::Result.where(annual: annual, round: round, solver_id: solver.id).take
    if res
      rank = res.rank
      points = res.score
    end

    if solver.grade_num.nil? || solver.grade_num.to_i == 0
      finish_year = ''
    else
      finish_year = solver.finish_year || ( year + 1 + maturity_grade - solver.grade_num.to_i )
      #finish_year = "#{finish_year}:#{solver.grade_num}"
      finish_year = "#{finish_year}"
    end
  
    spam_flag = 'Y'
    spam_date = solver.created_at.strftime('%Y-%m-%d')
    full_name = "#{solver.name} #{solver.last_name}"
    ex << [  solver.id, solver.name, solver.last_name, full_name,
             school.nil? ? 'ufo' : school.universal_id,
             "#{solver.street} #{solver.num}", (solver.psc||'').gsub(' ',''), solver.city,
             'cz', solver.email,
             finish_year,
             points, rank,
             spam_flag, spam_date,
             #solver.grade_num,
             ] 
  end
  
  return ex.map{  |row| row.join("\t") + "\n" }.join

end


def main 
  round_max = Sosna::Config.where(key: 'round').take.value.to_i
  annual = Sosna::Config.where(key: 'annual').take.value.to_i
  round_max = 6 if round_max == 100

  files = []
  dir = "ovvp"
  index_path = "ovvp.index.txt"
  (round_max .. round_max ).each do |round|

    file = "ovvp.#{annual}.#{round}.txt"
    File.open("#{dir}/#{file}", 'w') do |f| 
        f.write print_round(annual, round)
    end
    files << file
    "#{annual}.#{round}.txt"
  end
  File.open("#{dir}/#{index_path}", 'w') do |f|
    f.write(files.join("\n")+"\n")
  end
  print "created #{dir}/#{index_path}, #{files.map{|f| "#{dir}/#{f}"}.join(',')}.\n"
end
 
main
