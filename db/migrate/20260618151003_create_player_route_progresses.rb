class CreatePlayerRouteProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :player_route_progresses do |t|
      t.references :player, null: false, foreign_key: true
      t.references :route, null: false, foreign_key: true
      t.integer :progress, null: false, default: 0

      t.timestamps
    end

    add_index :player_route_progresses, [:player_id, :route_id], unique: true

  end
end
