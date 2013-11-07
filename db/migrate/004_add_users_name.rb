class AddUsersName < ActiveRecord::Migration
  def change
  #  us = User.all.each {|u| s = Sosna::Solver.find_by_user_id(u.id); if s; then  u.name = s.name; u.last_name=s.last_name; u.save ; end   }
      add_column :users, :name, :string
      add_column :users, :last_name, :string
  end
end
