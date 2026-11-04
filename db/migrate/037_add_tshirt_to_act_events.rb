class AddTshirtToActEvents < ActiveRecord::Migration[7.2]
  def change
    add_column :act_events, :spec_tshirt, :boolean, default: false
    add_column :act_events, :spec_tshirt_detail, :string, default: "116,128,140,152,164,XS,S,M,L,XL,XXL"
    add_column :act_event_participants, :tshirt, :string, default: ""
    add_column :act_participants, :tshirt, :string, default: ""
  end
end
