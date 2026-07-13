class AddCraftingFoundations < ActiveRecord::Migration[8.1]
  def change
    add_column :weapons, :maintenance_level, :integer, default: 0, null: false
    add_column :weapons, :crafted, :boolean, default: false, null: false
    add_column :weapons, :craft_data, :text, default: "{}", null: false
    add_column :weapons, :crafted_by_name, :string

    add_column :items, :durability, :integer
    add_column :items, :max_durability, :integer

    add_column :npcs, :craft_fee_multiplier, :decimal, precision: 5, scale: 2, default: 1.0, null: false
    add_column :npcs, :maintenance_fee_multiplier, :decimal, precision: 5, scale: 2, default: 1.0, null: false
    add_column :npcs, :enhance_fee_multiplier, :decimal, precision: 5, scale: 2, default: 1.0, null: false
  end
end
