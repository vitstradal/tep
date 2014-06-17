class AddSolversSolutionForm < ActiveRecord::Migration
  def change
      add_column :sosna_solvers, :solution_form, :text, :default => 'tep'
  end
end
