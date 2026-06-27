class AddTriggerAffinityToNpcQuests < ActiveRecord::Migration[8.1]
  def change
    add_column :npc_quests, :trigger_affinity, :integer
  end
end
