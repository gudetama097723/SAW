class AddFoundRestaurantToPlayerTownDiscoveries < ActiveRecord::Migration[8.1]
  def change
    add_column :player_town_discoveries, :found_restaurant, :boolean, default: false, null: false
    add_column :players, :found_restaurant, :boolean, default: false, null: false
  end
end
