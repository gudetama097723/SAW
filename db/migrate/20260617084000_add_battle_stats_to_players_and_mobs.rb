class AddBattleStatsToPlayersAndMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :level, :integer, default: 1, null: false
    add_column :players, :exp, :integer, default: 0, null: false
    add_column :players, :max_hp, :integer, default: 100, null: false
    add_column :players, :strength, :integer, default: 1, null: false
    add_column :players, :agility, :integer, default: 1, null: false
    add_column :players, :stat_points, :integer, default: 0, null: false

    add_column :mobs, :durability, :integer, default: 0, null: false
    add_column :mobs, :exp_reward, :integer, default: 10, null: false
  end
end
