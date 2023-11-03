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
if false
  User.delete_all

  users = User.create([
             {:email => "adm@pikomat.mff.cuni.cz", :roles => [:admin, :morg, :org, :user],  :password => "adm je pes", :name => "Tonda", :last_name => "Hejný"},
             {:email => "usr@pikomat.mff.cuni.cz", :roles => [:user],                :password => "usr je pes", :name => "David", :last_name => "Hájek"},
             {:email => "org@pikomat.mff.cuni.cz", :roles => [:org, :user],          :password => "org je pes", :name => "Terka", :last_name => "Kubínová"},
        ])

  users.each { |u| u.confirm }

end

if false
  Event.delete_all

  events = Event.create([
    { :event_start => Time.current.tomorrow, :event_end => Time.current.tomorrow, :title => "Prvni pikostreda", :body => "Tato pikostreda bude fakt super!", :event_info_url => "https://pikomat.mff.cuni.cz/setkani/vikendovky/vanocka2023", :visible => "everyone" },
    { :event_start => Time.current.yesterday.yesterday, :event_end => Time.current.yesterday, :title => "První víkendovka", :body => "Tato víkendovka bude fakt super!", :event_info_url => "https://pikomat.mff.cuni.cz/setkani/vikendovky/vyprava_do_skal2023/index", :visible => "org" },
  ])
end

if false
  EventParticipant.delete_all

  event_participants = EventParticipant.create([
    { :event_id => 5, :user_id => 16, :status => "yes"
    },
    { :event_id => 5, :user_id => 17, :status => "maybye"
    },
    { :event_id => 5, :user_id => 18, :status => "no"
    },
  ])
end

pp User.all

pp Event.all
