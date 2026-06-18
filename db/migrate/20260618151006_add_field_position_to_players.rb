class AddFieldPositionToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :field_position, :integer
    add_column :players, :field_route_id, :integer, null: false, default: 0
  end
end
