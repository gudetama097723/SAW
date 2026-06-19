class CreateWeaponEvolutionRules < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_evolution_rules do |t|
      t.string :source_weapon_name, null: false
      t.string :target_weapon_name, null: false
      t.integer :required_enhancement_level, default: 10, null: false
      t.integer :required_player_level, default: 1, null: false
      t.integer :required_floor
      t.string :blacksmith_location_name
      t.text :required_materials_data, default: "{}", null: false
      t.timestamps
    end

    add_index :weapon_evolution_rules, :source_weapon_name
  end
end
