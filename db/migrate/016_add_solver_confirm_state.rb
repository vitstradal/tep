class AddSolverConfirmState < ActiveRecord::Migration
  def change
      # 'conf' confirmed
      # 'none' unconfirmed
      # 'need' need confirm
      add_column :sosna_solvers, :confirm_state, :text, default: 'none'
  end
end
