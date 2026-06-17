class AddFoundInnToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :found_inn, :boolean, default: false, null: false
  end
end
