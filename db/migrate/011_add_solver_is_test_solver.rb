class AddSolverIsTestSolver < ActiveRecord::Migration
  def change
      add_column :sosna_solvers, :is_test_solver, :boolean, default: false, null: false
  end
end
