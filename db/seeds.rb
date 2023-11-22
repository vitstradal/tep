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
  User.delete_all

  users = User.create([
             {:email => "adm@pikomat.mff.cuni.cz", :roles => [:admin, :morg, :org, :user],  :password => "adm je pes", :name => "Antonín", :last_name => "Hejný"},
             {:email => "usr@pikomat.mff.cuni.cz", :roles => [:user],                :password => "usr je pes", :name => "David", :last_name => "Hájek"},
             {:email => "org@pikomat.mff.cuni.cz", :roles => [:org, :user],          :password => "org je pes", :name => "Tereza", :last_name => "Kubínová"},
             {:email => "morg@pikomat.mff.cuni.cz", :roles => [:morg, :org, :user],          :password => "morg je pes", :name => "František", :last_name => "Steinhauser"},
             {:email => "antonin.hejny@gmail.com", :roles => [:user],          :password => "usr je pes", :name => "Martin", :last_name => "Švanda"},
        ])
  users.each { |u| u.confirm }
end
