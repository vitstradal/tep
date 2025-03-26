class AddMedicAndReturnPlaceToActEvents < ActiveRecord::Migration[7.2]
  def change
      add_column :act_events, :event_medic, :string, default:  ""
      add_column :act_events, :spec_place_return, :boolean, default: false
      add_column :act_events, :spec_place_return_detail, :string, default: ""

      add_column :act_event_participants, :place_return, :string, default:  ""
  end
end
