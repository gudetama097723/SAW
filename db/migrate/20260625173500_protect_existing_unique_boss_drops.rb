class ProtectExistingUniqueBossDrops < ActiveRecord::Migration[8.1]
  def up
    names = unique_boss_drop_names
    return if names.empty?

    quoted_names = names.map { |name| connection.quote(name) }.join(", ")
    execute <<~SQL.squish
      UPDATE items
      SET unique_item = 1,
          discardable = 0,
          protected_from_death_penalty = 1
      WHERE category = 'drop'
        AND name IN (#{quoted_names})
    SQL
  end

  def down
    # Existing player inventory may have been intentionally protected after this point.
  end

  private

  def unique_boss_drop_names
    reward_names = select_values(<<~SQL.squish)
      SELECT reward_data
      FROM mobs
      WHERE boss_type != 'normal'
    SQL
      .flat_map { |reward_data| reward_drop_names(reward_data) }

    part_drop_names = select_values(<<~SQL.squish)
      SELECT mob_parts.drop_item_name
      FROM mob_parts
      INNER JOIN mobs ON mobs.id = mob_parts.mob_id
      WHERE mobs.boss_type != 'normal'
        AND mob_parts.drop_item_name IS NOT NULL
        AND mob_parts.drop_item_name != ''
    SQL

    (reward_names + part_drop_names).compact.uniq
  end

  def reward_drop_names(reward_data)
    reward = JSON.parse(reward_data.presence || "{}")
    Array(reward["items"]).filter_map do |item|
      category = item["category"].presence || "drop"
      item["name"] if category == "drop"
    end
  rescue JSON::ParserError
    []
  end
end
