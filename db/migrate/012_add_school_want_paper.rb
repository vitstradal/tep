class AddSchoolWantPaper < ActiveRecord::Migration
  def change
      add_column :sosna_schools, :want_paper, :boolean, default: false, null: false
  end
end
