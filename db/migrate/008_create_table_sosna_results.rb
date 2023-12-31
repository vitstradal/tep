class CreateTableSosnaResults < ActiveRecord::Migration
  def change
    create_table :sosna_results do |t|
      t.integer :annual     # ročník
      t.integer :round      # serie
      t.integer :solver_id  # řešitel
      t.text    :comment    # za ktere priklady jsou body

      t.integer :score      # počet bodů
      t.integer :round_score # počet bodů
      t.integer :rank          # poradi
      t.integer :rank_to       # poradi do
      t.integer :class_rank    # poradi v rocniku
      t.integer :class_rank_to # poradi v rocniku

      t.timestamps
    end
    add_index(:sosna_results, [:solver_id, :annual, :round ], unique: true )
  end
end

