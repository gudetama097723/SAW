class AddReturningToPlayerRouteProgresses < ActiveRecord::Migration[8.0]
  def change
    add_column :player_route_progresses, :returning, :boolean, null: false, default: false
  end
end
