class AddLevelAndRewardColumnsToBattleEnemiesAndMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :battle_enemies, :enemy_level, :integer, null: false, default: 1
    add_column :battle_enemies, :enemy_max_hp, :integer
    add_column :mobs, :col_min, :integer, null: false, default: 1
    add_column :mobs, :col_max, :integer, null: false, default: 3
  end
end
