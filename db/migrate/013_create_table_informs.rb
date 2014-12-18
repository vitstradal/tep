class CreateTableInforms < ActiveRecord::Migration
  def change
    create_table :informs do |t|
      t.string :form
      t.string :data
      t.timestamps
    end
    add_index(:informs, :form);
  end
end
