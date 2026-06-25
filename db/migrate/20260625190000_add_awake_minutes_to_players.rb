class AddAwakeMinutesToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :awake_minutes_since_sleep, :integer, default: 0, null: false
  end
end
