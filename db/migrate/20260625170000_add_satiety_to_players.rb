class AddSatietyToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :satiety, :decimal, precision: 8, scale: 3, default: 100, null: false
  end
end
