class CreateNpcAffinityRules < ActiveRecord::Migration[8.1]
  def change
    change_column_default :npc_discoveries, :affinity, from: 0, to: 1
    add_column :npc_discoveries, :last_chat_affinity_day, :integer
    add_column :npc_discoveries, :last_gift_affinity_day, :integer
    add_column :npc_discoveries, :affinity_event_flags, :text, null: false, default: "{}"

    reversible do |dir|
      dir.up do
        execute "UPDATE npc_discoveries SET affinity = 1 WHERE affinity < 1"
      end
    end

    create_table :npc_affinity_rules do |t|
      t.references :npc, null: false, foreign_key: true
      t.string :action_type, null: false
      t.string :target_key
      t.integer :affinity_gain, null: false, default: 0
      t.boolean :daily_limit, null: false, default: false
      t.integer :required_affinity, null: false, default: 0
      t.text :conditions_json, null: false, default: "{}"
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :npc_affinity_rules, [:npc_id, :action_type, :target_key], name: "index_npc_affinity_rules_lookup"
  end
end
