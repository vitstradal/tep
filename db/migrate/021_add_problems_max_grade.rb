class AddProblemsMaxGrade < ActiveRecord::Migration
  def change
    add_column :sosna_problems, :level, :string, null: false, default: 'pi'
  end
end
