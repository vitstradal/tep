class AddSolversHowIMetPikomat < ActiveRecord::Migration
  def change
    add_column :sosna_solvers, :how_i_met_pikomat, :string, null: false, default: ''

  end
end
