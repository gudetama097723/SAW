class AddReachedDestinationToPlayerRouteProgresses < ActiveRecord::Migration[8.1]
  def change
    add_column :player_route_progresses, :reached_destination, :boolean, null: false, default: false
  end
end
