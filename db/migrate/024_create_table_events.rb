class CreateTableEvents < ActiveRecord::Migration
  def change
    create_table :act_participants do |t|
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
      t.string :activated, :default => "full"
      t.timestamps
    end

    create_table :act_event_categories, id: false, primary_key: [:code] do |t|
      t.string :code, limit: 2
      t.index :code, unique: true
      t.string :name
      t.integer :idx, :default => 0
      t.boolean :multi_day, :default => true
      t.text :description, :default => ""
      t.string :visible, :default => "ev"
      t.boolean :restrictions_electible, :default => true
      t.boolean :mass_spec_electible, :default => true
      t.string :activation_needed_default, :default => "full"
      t.timestamps
    end

    create_table :act_events do |t|
      t.date :event_start
      t.date :event_end
      t.string :title
      t.text :body
      t.string :event_category, :default => "ot"
      t.string :event_info_url, :default => ""
      t.string :event_photos_url, :default => ""
      t.string :visible, :default => "ev"
      t.boolean :spec_place, :default => false
      t.string :spec_place_detail, :default => ""
      t.boolean :spec_participant, :default => false
      t.boolean :spec_mass, :default => false
      t.string :bonz_org, :default => ""
      t.boolean :bonz_parent, :default => false
      t.boolean :limit_num_participants, :default => false
      t.integer :max_participants, :default => 0
      t.boolean :enable_only_specific_participants, :default => false
      t.boolean :enable_only_specific_substitutes, :default => false
      t.boolean :enable_only_specific_organisers, :default => false
      t.boolean :uninvited_participants_dont_see, :default => false
      t.boolean :uninvited_organisers_dont_see, :default => false
      t.string :activation_needed, :default => "full"
      t.boolean :limit_maybe, :default => false
      t.date :maybe_deadline
      t.timestamps
    end
      
    create_table :act_event_participants do |t|
      t.integer :event_id, index: true
      t.integer :participant_id, index: true
      t.string :status, :default => "yes"
      t.string :note, :default => ""
      t.string :place, :default => ""
      t.string :participant_info, :default => ""
      t.boolean :mass, :default => false
      t.string :chosen, :default => "none"
      t.timestamps
    end

    add_index :act_event_participants, [:event_id, :participant_id], unique: true

    create_table :act_event_invitations do |t|
      t.integer :event_id, index: true
      t.integer :participant_id, index: true
      t.string :chosen, :default => "participant"
    end

    add_index :act_event_invitations, [:event_id, :participant_id], unique: true
  end
end
