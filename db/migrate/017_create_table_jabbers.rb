class CreateTableJabbers < ActiveRecord::Migration
  def change
    create_table :jabbers do |t|
      t.belongs_to :user, index: { unique: true }   # uživatel
      t.text       :jid     # celý login ie vitas@pikomat.mff.cuni.cz
      t.text       :nick    # krátké jméno
    end
    add_index(:jabbers, :jid, unique: true )
  end
end
