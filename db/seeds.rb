# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ :name => 'Chicago' }, { :name => 'Copenhagen' }])
#   Mayor.create(:name => 'Daley', :city => cities.first)


schools = SosnaSchool.create([
          { :name => '1zakladni', :short => '1zs', 
            :street => 'narodni', :house_num => 1, :city => 'Brno', :psc => "11111",
          },
          { :name => '2zakladni', :short => '2zs', 
            :street => 'narodni', :house_num => 2, :city => 'Brno', :psc => "11111",
          },
        ]);

#schools = Users.create([
#        ]);
#

