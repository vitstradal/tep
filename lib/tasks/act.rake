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

  desc 'Porovnej datum narození účastníků s řešiteli téhož uživatele; FIX=1 opraví posun o den podle řešitele'
  task birth_check: :environment do
    fix = ENV['FIX'] == '1'
    parse = ->(s) { (m = s.to_s.match(/(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})/)) && (Date.new(m[3].to_i, m[2].to_i, m[1].to_i) rescue nil) }
    hours = Hash.new(0)
    shifted, other, conflict, fixed = [], [], [], 0

    Act::Participant.where.not(birth: nil).find_each do |par|
      utc = par.birth.utc
      hours[utc.hour] += 1
      next if par.user_id.nil?
      solver_dates = Sosna::Solver.where(user_id: par.user_id).pluck(:birth).map(&parse).compact.uniq
      next if solver_dates.empty?
      line = "  par #{par.id} #{par.name} #{par.last_name}: účastník #{utc.strftime('%-d. %-m. %Y %H:%M')} UTC, řešitel #{solver_dates.map { |d| d.strftime('%-d. %-m. %Y') }.join(' / ')}"
      if solver_dates.size > 1
        conflict << line
        next
      end
      solver = solver_dates.first
      diff = (solver - utc.to_date).to_i
      next if diff == 0
      if diff.abs == 1
        shifted << line
        if fix
          par.update_column(:birth, Time.utc(solver.year, solver.month, solver.day))
          fixed += 1
        end
      else
        other << line
      end
    end

    puts "Hodina (UTC) uloženého data narození: #{hours.sort.map { |h, n| "#{h}h: #{n}" }.join(', ')}"
    puts "Posun o den proti řešiteli (#{shifted.size}):", *shifted
    puts "Jiný rozdíl – řeší člověk (#{other.size}):", *other
    puts "Řešitelé téhož uživatele se neshodnou (#{conflict.size}):", *conflict
    puts fix ? "Opraveno #{fixed} účastníků podle řešitele." : "Nic neměněno; opravu posunů spustí FIX=1."
  end
end
