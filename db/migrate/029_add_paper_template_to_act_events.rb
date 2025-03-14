class AddPaperTemplateToActEvents < ActiveRecord::Migration[6.0]
  def change
      add_column :act_events, :paper_template, :user_agent, :text
  end
end
