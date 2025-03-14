class AddPaperTemplateToActEvents < ActiveRecord::Migration[6.0]
  def change
      add_column :act_events, :paper_template, :text, null: false, default:  ''
  end
end
