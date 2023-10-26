class AddProblemsMaxGrade < ActiveRecord::Migration
  def change
    add_column :sosna_problems, :max_grade, :integer, null: false, default: 9
  end
end
