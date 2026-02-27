class AddEventSklepUrlToActEvents < ActiveRecord::Migration[7.2]
  def change
      add_column :act_events, :event_sklep_url, :string, default:  ""
  end
end
