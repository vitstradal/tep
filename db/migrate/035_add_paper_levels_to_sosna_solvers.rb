##
# Které papírové letáky (zadání) řešiteli posílat: junior a/nebo senior.
# Dosud dostávali všichni papíroví oba letáky. Junior je jen do 6. ročníku.
# Stávající řešitele doplní rake sosna:backfill_paper_levels.
class AddPaperLevelsToSosnaSolvers < ActiveRecord::Migration[7.2]
  def change
    add_column :sosna_solvers, :paper_jr, :boolean, default: false
    add_column :sosna_solvers, :paper_pi, :boolean, default: false
  end
end
