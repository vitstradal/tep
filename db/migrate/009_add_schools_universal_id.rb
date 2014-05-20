class AddSchoolsUniversalId < ActiveRecord::Migration
  def change
      add_column :sosna_schools, :universal_id, :text
  end
end
