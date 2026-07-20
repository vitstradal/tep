##
# Role účasti na akci ('org' | 'participant' | NULL = nezjištěno).
# Historická data neexistují — u starých akcí zůstává NULL, letošní školní
# rok doplní rake act:backfill_roles podle současného stavu účtů.
class AddRoleToActEventParticipants < ActiveRecord::Migration[7.2]
  def change
    add_column :act_event_participants, :role, :text
  end
end
