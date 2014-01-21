class CreateTablePenalisations < ActiveRecord::Migration
  def change
    create_table :sosna_penalisations do |t|
      t.integer :annual     # ročník
      t.integer :round      # serie
      t.integer :solver_id  # řešitel

      t.integer :score      # počet bodů (záporné)
      t.text :title         # důvod

      t.timestamps
    end
    add_index(:sosna_penalisations, [:solver_id, :annual, :round ], unique: true )
  end
end

