class AddIndexSolutions < ActiveRecord::Migration
  def change
      add_index(:sosna_solutions, [:solver_id, :problem_id], unique: true )
  end
end
