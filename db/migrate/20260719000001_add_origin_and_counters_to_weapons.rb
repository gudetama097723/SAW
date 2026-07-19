class AddOriginAndCountersToWeapons < ActiveRecord::Migration[8.1]
  def up
    add_column :weapons, :origin, :string, default: "shop", null: false
    add_column :weapons, :critical_hit_count, :integer, default: 0, null: false
    add_column :weapons, :kill_count, :integer, default: 0, null: false

    execute <<~SQL.squish
      UPDATE weapons SET origin = 'crafted' WHERE crafted = 1
    SQL
    execute <<~SQL.squish
      UPDATE weapons SET origin = 'starter'
      WHERE discardable = 0 AND protected_from_death_penalty = 1
    SQL
  end

  def down
    remove_column :weapons, :kill_count
    remove_column :weapons, :critical_hit_count
    remove_column :weapons, :origin
  end
end
