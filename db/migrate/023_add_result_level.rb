class AddResultLevel < ActiveRecord::Migration
  def change
    add_column :sosna_results, :level, :string, null: false, default: 'pi'
    remove_index "sosna_results", name: "index_sosna_results_on_solver_id_and_annual_and_round"
    add_index "sosna_results", ["solver_id", "annual", "level", "round"], name: "index_sosna_results_on_solver_id_annual_level_round", unique: true
  end
end
