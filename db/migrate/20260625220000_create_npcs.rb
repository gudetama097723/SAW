class CreateNpcs < ActiveRecord::Migration[8.1]
  def change
    create_table :npcs do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :npc_type, null: false, default: "general"
      t.string :placement_type, null: false
      t.references :location, foreign_key: true
      t.references :field_area, foreign_key: true
      t.string :facility_key
      t.string :dungeon_key
      t.string :position_key
      t.integer :sort_order, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :description
      t.text :metadata_json, null: false, default: "{}"

      t.timestamps
    end

    add_index :npcs, :code, unique: true
    add_index :npcs, [:placement_type, :location_id]
    add_index :npcs, [:placement_type, :field_area_id]
    add_index :npcs, [:placement_type, :facility_key]
    add_index :npcs, [:placement_type, :dungeon_key]
  end
end
