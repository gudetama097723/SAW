class CreateNpcAffinityCapRules < ActiveRecord::Migration[8.1]
  def change
    add_column :npcs, :initial_affinity_cap, :integer, null: false, default: 60
    add_column :npc_discoveries, :affinity_cap, :integer, null: false, default: 60
    add_column :npc_discoveries, :affinity_cap_flags, :text, null: false, default: "{}"

    create_table :npc_affinity_cap_rules do |t|
      t.references :npc, null: false, foreign_key: true
      t.integer :cap_value, null: false
      t.string :unlock_type, null: false
      t.string :unlock_key, null: false
      t.integer :required_affinity, null: false, default: 0
      t.text :conditions_json, null: false, default: "{}"
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :npc_affinity_cap_rules, [:npc_id, :unlock_type, :unlock_key], name: "index_npc_affinity_cap_rules_lookup"
  end
end
