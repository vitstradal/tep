class AddInformsUserAgent < ActiveRecord::Migration
  def change
      add_column :informs, :user_agent, :text, default: 'unknown'
  end
end
