class AllowNullFieldRouteIdOnPlayers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :players, :field_route_id, true
    change_column_default :players, :field_route_id, from: 0, to: nil

    change_column_null :players, :field_position, false, 0
    change_column_default :players, :field_position, from: nil, to: 0
  end
end
