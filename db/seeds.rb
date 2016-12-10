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
             {:email => "adm@pikomat.mff.cuni.cz", :roles => [:admin, :org, :user],  :password => "adm je pes"},
             {:email => "usr@pikomat.mff.cuni.cz", :roles => [:user],                :password => "usr je pes"},
             {:email => "org@pikomat.mff.cuni.cz", :roles => [:org, :user],          :password => "org je pes"},
        ])

  users.each { |u| u.confirm }

end


