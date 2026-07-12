class AddDefeatedCountToPlayerBossKills < ActiveRecord::Migration[8.1]
  def change
    add_column :player_boss_kills, :defeated_count, :integer, null: false, default: 0
  end
end
