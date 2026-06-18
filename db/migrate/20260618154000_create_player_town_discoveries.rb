class CreatePlayerTownDiscoveries < ActiveRecord::Migration[8.1]
  def change
    create_table :player_town_discoveries do |t|
      t.references :player, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.boolean :found_inn, null: false, default: false
      t.boolean :found_item_shop, null: false, default: false
      t.boolean :found_blacksmith, null: false, default: false

      t.timestamps
    end

    add_index :player_town_discoveries, [:player_id, :location_id], unique: true
  end
end
