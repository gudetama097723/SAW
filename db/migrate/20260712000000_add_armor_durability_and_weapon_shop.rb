class AddArmorDurabilityAndWeaponShop < ActiveRecord::Migration[8.1]
  def change
    add_column :armors, :durability, :integer, default: 100, null: false
    add_column :armors, :max_durability, :integer, default: 100, null: false
    add_column :player_town_discoveries, :found_weapon_shop, :boolean, default: false, null: false
    add_column :players, :found_weapon_shop, :boolean, default: false, null: false
  end
end
