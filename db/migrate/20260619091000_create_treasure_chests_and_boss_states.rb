class CreateTreasureChestsAndBossStates < ActiveRecord::Migration[8.1]
  def change
    create_table :treasure_chests do |t|
      t.references :route, null: false, foreign_key: true
      t.references :field_area, null: true, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.string :discovery_type, null: false, default: "fixed"
      t.integer :required_mapping, null: false, default: 0
      t.text :reward_data, null: false, default: "{}"
      t.boolean :respawnable, null: false, default: false

      t.timestamps
    end

    create_table :player_treasure_chests do |t|
      t.references :player, null: false, foreign_key: true
      t.references :treasure_chest, null: false, foreign_key: true
      t.boolean :found, null: false, default: false
      t.boolean :opened, null: false, default: false
      t.datetime :opened_at

      t.timestamps
    end
    add_index :player_treasure_chests, [:player_id, :treasure_chest_id], unique: true, name: "index_player_treasure_unique"

    add_reference :mobs, :field_area, foreign_key: true
    add_reference :mobs, :route, foreign_key: true
    add_column :mobs, :boss_type, :string, null: false, default: "normal"
    add_column :mobs, :reward_data, :text, null: false, default: "{}"

    create_table :player_boss_kills do |t|
      t.references :player, null: false, foreign_key: true
      t.references :mob, null: false, foreign_key: true
      t.boolean :found, null: false, default: false
      t.boolean :defeated, null: false, default: false
      t.datetime :defeated_at

      t.timestamps
    end
    add_index :player_boss_kills, [:player_id, :mob_id], unique: true, name: "index_player_boss_kills_unique"
  end
end
