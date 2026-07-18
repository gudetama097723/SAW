class AddFieldRouteOriginToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :field_route_origin_route_id, :integer
    add_column :players, :field_route_origin_position, :integer
    add_index :players, :field_route_origin_route_id
  end
end
