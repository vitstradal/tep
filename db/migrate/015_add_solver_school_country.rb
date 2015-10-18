class AddSolverSchoolCountry < ActiveRecord::Migration
  def change
      add_column :sosna_schools, :country, :text, default: 'cz'
      add_column :sosna_solvers, :country, :text, default: 'cz'
  end
end
