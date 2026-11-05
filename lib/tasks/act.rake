##
# Údržbové tasky akcí.
namespace :act do
  desc 'Doplň role účastí (org/participant) pro akce letošního školního roku podle současného stavu účtů; starší akce nech nezjištěné'
  task backfill_roles: :environment do
    today = Date.today
    sy_start = today.month >= 9 ? Date.new(today.year, 9, 1) : Date.new(today.year - 1, 9, 1)
    count = 0
    Act::Event.where('event_start >= ?', sy_start).find_each do |ev|
      Act::EventParticipant.where(event_id: ev.id, role: nil)
                           .includes(participant: :user).each do |ep|
        # ukládá se jen stav odvozený z účtu; odhad z ročníku zůstává
        # zobrazovací záležitost (role_guessed?), neukládá se
        next if ep.participant.nil? || ep.participant.user.nil?
        ep.update_columns(role: ep.participant.user.org? ? 'org' : 'participant')
        count += 1
      end
    end
    puts "act:backfill_roles: doplněno #{count} rolí (akce od #{sy_start})"
  end

  birth_header = %w[id jmeno prijmeni email ulozeno_utc zobrazuje resitel navrh duvod]
  parse_cz_date = lambda do |str|
    m = str.to_s.match(/(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})/)
    m && (Date.new(m[3].to_i, m[2].to_i, m[1].to_i) rescue nil)
  end
  cz_date = ->(date) { date&.strftime('%-d.%-m.%Y') }

  desc 'Vyexportuj data narození všech účastníků s návrhem opravy do CSV (FILE=, výchozí tmp/birth.csv); sloupec navrh pak uprav a pusť act:birth_import'
  task birth_export: :environment do
    require 'csv'
    file = ENV['FILE'] || Rails.root.join('tmp', 'birth.csv').to_s
    this_year = Date.current.year
    plausible = ->(d) { d.year.between?(this_year - 60, this_year - 6) }
    swap = ->(d) { Date.new(d.year, d.day, d.month) rescue nil }
    counts = Hash.new(0)
    rows = []
    Act::Participant.order(:last_name, :name).find_each do |par|
      utc = par.birth&.utc
      shown = utc&.to_date
      fixed = utc && (utc.hour >= 12 ? shown + 1 : shown)
      solver = par.user_id ? Sosna::Solver.where(user_id: par.user_id).pluck(:birth).map(&parse_cz_date).compact.uniq : []
      tz = fixed != shown ? ' (po opravě časové zóny)' : ''
      proposal, why =
        if fixed.nil? then [solver.size == 1 ? solver.first : nil, 'nevyplněno']
        elsif solver.empty? then [fixed, "bez řešitele#{tz}"]
        elsif solver.include?(fixed) then [fixed, "sedí s řešitelem#{tz}"]
        elsif !plausible.(fixed) && solver.count(&plausible) == 1 then [solver.find(&plausible), 'nesmyslný rok u účastníka, podle řešitele']
        elsif plausible.(fixed) && solver.none?(&plausible) then [fixed, "nesmyslný rok u řešitele, podle účastníka#{tz}"]
        elsif solver.include?(fixed + 1) then [fixed + 1, 'řešitel o den později, podle řešitele']
        elsif solver.include?(swap.(fixed)) then [swap.(fixed), 'prohozený den a měsíc, podle řešitele']
        else [fixed, "ROZHODNI: liší se od řešitele#{tz}"]
        end
      counts[why.sub(tz, '')] += 1
      rows << [par.id, par.name, par.last_name, par.email, utc&.strftime('%Y-%m-%d %H:%M'), cz_date.(shown),
               solver.map { |d| cz_date.(d) }.join(' / '), cz_date.(proposal), why]
    end
    CSV.open(file, 'w', col_sep: ';') do |csv|
      csv << birth_header
      rows.sort_by { |r| r[8].start_with?('ROZHODNI') ? 0 : 1 }.each { |r| csv << r }
    end
    puts "act:birth_export: #{file}"
    counts.sort_by { |_, n| -n }.each { |why, n| puts "  #{why}: #{n}" }
  end

  desc 'Nastav data narození podle sloupce navrh v CSV z act:birth_export (FILE=); bez APPLY=1 jen vypíše změny'
  task birth_import: :environment do
    require 'csv'
    file = ENV['FILE'] || Rails.root.join('tmp', 'birth.csv').to_s
    apply = ENV['APPLY'] == '1'
    changed = 0
    CSV.foreach(file, col_sep: ';', headers: true) do |row|
      next if row['navrh'].to_s.strip.empty?
      date = parse_cz_date.(row['navrh'])
      abort "řádek id #{row['id']}: nečitelné datum '#{row['navrh']}'" unless date
      par = Act::Participant.find_by(id: row['id'])
      abort "účastník #{row['id']} neexistuje" unless par
      target = Time.utc(date.year, date.month, date.day)
      next if par.birth&.utc == target
      puts "  #{par.id} #{par.name} #{par.last_name}: #{par.birth&.utc&.strftime('%Y-%m-%d %H:%M') || '-'} -> #{cz_date.(date)}"
      par.update_column(:birth, target) if apply
      changed += 1
    end
    puts apply ? "act:birth_import: nastaveno #{changed} dat narození" : "act:birth_import: #{changed} změn; nic neuloženo, uložíš s APPLY=1"
  end
end
