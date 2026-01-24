class AddEventPikiUrlToActEvents < ActiveRecord::Migration[7.2]
  def change
      add_column :act_events, :event_piki_url, :string, default:  ""
  end
end
