class AddDistanceToBattleEnemies < ActiveRecord::Migration[8.1]
  def change
    add_column :battle_enemies, :distance, :string, default: "near", null: false
  end
end
