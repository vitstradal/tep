class CreateTableEvents < ActiveRecord::Migration
  def change
    create_table :event_categories, id: false, primary_key: [:code] do |t|
      t.string :code, limit: 2
      t.index :code, unique: true
      t.string :name
      t.integer :idx, :default => 0
      t.boolean :multi_day, :default => true
      t.text :description, :default => ""
      t.string :visible, :default => "ev"
      t.timestamps
    end

    create_table :events do |t|
      t.date :event_start
      t.date :event_end
      t.string :title
      t.text :body
      t.string :event_category, :default => "ot"
      t.string :event_info_url, :default => ""
      t.string :event_photos_url, :default => ""
      t.string :visible, :default => "ev"
      t.bool :spec_place, :default => false
      t.string :spec_place_detail, :default => ""
      t.bool :spec_scout, :default => false
      t.bool :spec_mass, :default => false
      t.string :bonz_org, :default => ""
      t.bool :bonz_parent, :default => false
      t.bool :limit_num_participants, :default => false
      t.integer :max_participants, :default => 0
      t.timestamps
    end
      
    create_table :event_participants do |t|
      t.belongs_to :event
      t.belongs_to :scout
      t.string :status, :default => "yes"
      t.string :note, :default => ""
      t.string :place, :default => ""
      t.string :scout_info, :default => ""
      t.boolean :mass, :default => false
      t.string :chosen, :default => "none"
      t.timestamps
    end

    add_index(:event_participants, :event)
    add_index(:event_participants, :scout)

    create_table :scouts do |t|
      t.belongs_to :user
      t.string :name
      t.string :last_name
      t.string :nickname, :default => ""
      t.string :sex, :default => "male"
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
