class AddSolversHowIMetPikomatDetail < ActiveRecord::Migration
  def change
    add_column :sosna_solvers, :how_i_met_pikomat_detail, :string, null: false, default: ''
    #add_column :sosna_solvers, :friend_who_told_me_about_pikomat, :string, null: false, default: ''
  end
end
