class RemoveLegacyWeaponUpgradeRecipes < ActiveRecord::Migration[8.1]
  def up
    drop_table :weapon_upgrade_recipes
  end

  def down
    create_table :weapon_upgrade_recipes do |t|
      t.string :weapon_name
      t.string :weapon_type
      t.integer :target_level, null: false
      t.integer :required_col, default: 0, null: false
      t.text :required_materials_data, default: "{}", null: false
      t.timestamps
    end
    add_index :weapon_upgrade_recipes, [ :weapon_name, :weapon_type, :target_level ], name: "index_weapon_upgrade_recipes_lookup"
  end
end
