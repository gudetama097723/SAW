class AddDiscoveredShopsToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :found_item_shop, :boolean, default: false, null: false
    add_column :players, :found_blacksmith, :boolean, default: false, null: false
  end
end
