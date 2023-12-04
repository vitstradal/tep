# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)


#schools = Sosna::School.create([
#          { :name => '1zakladni', :short => '1zs',
#            :street => 'narodni', :num => 1, :city => 'Brno', :psc => "11111",
#          },
#          { :name => '2zakladni', :short => '2zs',
#            :street => 'narodni', :num => 2, :city => 'Brno', :psc => "11111",
#          },
#        ])

require 'pp'
if true
  users = User.create([
             {:email => "adm@pikomat.mff.cuni.cz", :roles => [:admin, :morg, :org, :user],  :password => "adm je pes", :name => "Antonín", :last_name => "Hejný"},
             {:email => "usr@pikomat.mff.cuni.cz", :roles => [:user],                :password => "usr je pes", :name => "David", :last_name => "Hájek"},
             {:email => "org@pikomat.mff.cuni.cz", :roles => [:org, :user],          :password => "org je pes", :name => "Tereza", :last_name => "Kubínová"},
             {:email => "morg@pikomat.mff.cuni.cz", :roles => [:morg, :org, :user],          :password => "morg je pes", :name => "František", :last_name => "Steinhauser"},
             {:email => "antonin.hejny@gmail.com", :roles => [:user],          :password => "usr je pes", :name => "Martin", :last_name => "Švanda"},
        ])
  users.each { |u| u.confirm }

  scouts = Act::Scout.create([
    { user_id: 1, name: "Antonín", last_name: "Hejný", nickname: "Tonda", sex: "male", birth: "Sun, 02 Jan 2000 00:00:00 UTC +00:00", grade: "16", address: "Ulice 123", email: "antonin.hejny@gmail.com", parent_email: "a.hejny@centrum.cz", phone: "123456789", parent_phone: "987654321", eating_habits: "Jí vše :-)", health_problems: "Zdravotní problémy nemá", birth_number: "01234567891", health_insurance: "OZP", activated: "full"}
  ])

  event_categories = Act::EventCategory.create([
    { code: "we", name: "Pikostředa", idx: 0, multi_day: false, description: "Pravidlně od 19:00 na Karlíně", visible: "ev", restrictions_electible: false, activation_needed_default: "light"  },
    { code: "kl", name: "Kus ledu", idx: 100, multi_day: true, description: "Orgovské setkání pro konzultaci všeho možného", visible: "org", restrictions_electible: true, activation_needed_default: "full" }
  ])

  events = Act::Event.create([
    { event_start: "Tue, 02 Jan 2024", event_end: "Tue, 02 Jan 2024", title: "První Pikostředa", body: "Přineste si s sebou hroadu deskovek :D", event_category: "we" }
  ])

  event_participants = Act::EventParticipant.create([
    { event_id: 1, scout_id: 1, status: "yes", note: "Už se těším :)) " }           
  ])

  pp Act::EventParticipant.all
  pp Act::EventParticipant.primary_key
end
