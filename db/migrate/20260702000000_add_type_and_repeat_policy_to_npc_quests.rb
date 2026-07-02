class AddTypeAndRepeatPolicyToNpcQuests < ActiveRecord::Migration[8.1]
  def change
    add_column :npc_quests, :quest_type, :string, null: false, default: "npc"
    add_column :npc_quests, :repeat_policy_json, :text, null: false, default: "{}"
    add_index :npc_quests, :quest_type
  end
end
