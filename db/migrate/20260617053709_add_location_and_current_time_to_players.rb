class AddLocationAndCurrentTimeToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_reference :players, :location, null: true, foreign_key: true
    add_column :players, :current_time, :integer, default: 480
  end
end
