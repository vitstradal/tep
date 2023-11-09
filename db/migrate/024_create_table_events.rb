class CreateTableEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.date :event_start
      t.date :event_end
      t.string :title
      t.text :body
      t.string :category, :default => "ot"
      t.string :event_info_url, :default => ""
      t.string :visible, :default => "org"
      t.timestamps
    end
      
    create_table :event_participants do |t|
      t.belongs_to :event
      t.belongs_to :scout
      t.string :status, :default => "yes"
      t.string :note, :default => ""
      t.timestamps
    end

    add_index(:event_participants, :event)
    add_index(:event_participants, :scout)

    create_table :scouts do |t|
      t.belongs_to :user
      t.string :name
      t.string :last_name
      t.string :nickname, :default => ""
      t.datetime :birth
      t.integer :grade
      t.string :address
      t.string :email
      t.string :parent_email
      t.string :phone
      t.string :parent_phone
      t.text :eating_habits, :default => ""
      t.text :health_problems, :default => ""
      t.text :birth_number
      t.string :health_insurance
      t.boolean :activated, :default => true
      t.timestamps
    end
  end
end
