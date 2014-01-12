class AddSolutionsHasPaperMail < ActiveRecord::Migration
  def change
      add_column :sosna_solutions, :has_paper_mail, :boolean, default: false, null: false
  end
end
