class AddProblemUpdated < ActiveRecord::Migration[7.2]
  def change
    add_column :sosna_problems, :updated, :boolean, null: false, default: false
  end
end
