class AddPenalisationLevel < ActiveRecord::Migration
  def change
    add_column :sosna_penalisations, :level, :string, null: false, default: 'pi'
    remove_index "sosna_penalisations", name: "index_sosna_penalisations_on_solver_id_and_annual_and_round"
    add_index "sosna_penalisations", ["solver_id", "annual", "level", "round"], name: "index_sosna_penalisations_on_solver_id_annual_level_round", unique: true
  end
end
