class BackfillStarterLegArmor < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      INSERT INTO armors
        (player_id, name, armor_type, slot, rarity, defense, weight, hp_bonus,
         strength_bonus, agility_bonus, durability, max_durability, equipped,
         favorite, discardable, protected_from_death_penalty, unique_item,
         status_resistance_data, created_at, updated_at)
      SELECT players.id, 'レザートラウザー', '革鎧', 'legs', 'common', 1, 1, 0,
             0, 1, 100, 100, TRUE, FALSE, TRUE, FALSE, FALSE, '{}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM players
      WHERE EXISTS (
        SELECT 1 FROM armors starter
        WHERE starter.player_id = players.id
          AND starter.name IN ('レザーチュニック', 'レザーブーツ')
      )
      AND NOT EXISTS (
        SELECT 1 FROM armors legs
        WHERE legs.player_id = players.id AND legs.slot = 'legs'
      )
    SQL
  end

  def down
    # Existing player equipment is intentionally preserved on rollback.
  end
end
