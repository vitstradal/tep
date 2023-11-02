class CreateTableEvents < ActiveRecord::Migration
  def change
    create_table :events do |t|
      t.date :event_start
      t.date :event_end
      t.string :url
      t.timestamps
    end
      
    create_table :event_participants do |t|
      t.belongs_to :event
      t.belongs_to :user
      t.string :status
      t.string :note
      t.timestamps
    end

    add_index(:event_participants, :event)
    add_index(:event_participants, :user)
  end
end
