class AddManagementSystems < ActiveRecord::Migration[8.0]
  def change
    add_column :players, :current_month, :integer, default: 1, null: false
    add_column :players, :current_day, :integer, default: 1, null: false
    add_column :players, :base_col, :integer, default: 0, null: false

    add_column :items, :weight, :decimal, precision: 8, scale: 2, default: "0.10", null: false
    add_column :items, :discardable, :boolean, default: true, null: false
    add_column :items, :protected_from_death_penalty, :boolean, default: false, null: false
    add_column :items, :unique_item, :boolean, default: false, null: false
    add_column :items, :quest_item, :boolean, default: false, null: false

    add_column :weapons, :favorite, :boolean, default: false, null: false
    add_column :weapons, :discardable, :boolean, default: true, null: false
    add_column :weapons, :protected_from_death_penalty, :boolean, default: false, null: false
    add_column :weapons, :unique_item, :boolean, default: false, null: false
    add_column :weapons, :weight, :decimal, precision: 8, scale: 2, default: "5.00", null: false
    add_column :weapons, :strength_ratio, :integer, default: 70, null: false
    add_column :weapons, :agility_ratio, :integer, default: 30, null: false
    add_column :weapons, :description, :text

    add_column :armors, :favorite, :boolean, default: false, null: false
    add_column :armors, :discardable, :boolean, default: true, null: false
    add_column :armors, :protected_from_death_penalty, :boolean, default: false, null: false
    add_column :armors, :unique_item, :boolean, default: false, null: false

    create_table :player_bases do |t|
      t.references :player, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.string :base_type, null: false, default: "home"
      t.boolean :active, null: false, default: true
      t.integer :rent, null: false, default: 0
      t.boolean :rent_overdue, null: false, default: false
      t.integer :storage_limit, null: false, default: 20
      t.timestamps
    end

    create_table :storage_items do |t|
      t.references :player_base, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false, default: "misc"
      t.integer :quantity, null: false, default: 0
      t.timestamps
    end
    add_index :storage_items, [:player_base_id, :name, :category], unique: true

    create_table :weapon_upgrade_recipes do |t|
      t.string :weapon_name
      t.string :weapon_type
      t.integer :target_level, null: false
      t.integer :required_col, null: false, default: 0
      t.text :required_materials_data, null: false, default: "{}"
      t.timestamps
    end
    add_index :weapon_upgrade_recipes, [:weapon_name, :weapon_type, :target_level], name: "index_weapon_upgrade_recipes_lookup"
  end
end
