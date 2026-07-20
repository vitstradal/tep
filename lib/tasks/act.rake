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
end
