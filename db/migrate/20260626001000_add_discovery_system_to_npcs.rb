class AddDiscoverySystemToNpcs < ActiveRecord::Migration[8.1]
  def change
    add_column :npcs, :discovery_rate, :integer, default: 100, null: false
    add_column :npcs, :repeat_discovery_required, :boolean, default: false, null: false
    add_column :npcs, :discovery_conditions_json, :text, default: "{}", null: false

    create_table :npc_discoveries do |t|
      t.references :player, null: false, foreign_key: true
      t.references :npc, null: false, foreign_key: true
      t.boolean :currently_available, null: false, default: false
      t.integer :discovered_count, null: false, default: 0
      t.datetime :first_discovered_at
      t.datetime :last_discovered_at
      t.datetime :last_spoken_at

      t.timestamps
    end

    add_index :npc_discoveries, [:player_id, :npc_id], unique: true
    add_index :npc_discoveries, [:player_id, :currently_available]
  end
end
