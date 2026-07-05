class MobDropCatalog
  DROP_CHANCE = 50
  PART_DROP_MIN_CHANCE = 80

  DropDefinition = Struct.new(:mob_name, :item_name, :category, :weight, :min_level, :max_level, keyword_init: true) do
    def available_for_level?(level)
      effective_level = [level.to_i, 1].max
      effective_level >= min_level.to_i && effective_level <= max_level.to_i
    end
  end

  def self.roll_defeat_drop(mob, enemy_level: nil)
    return nil unless mob
    return nil unless rand(100) < DROP_CHANCE

    weighted_sample(definitions_for(mob, enemy_level: enemy_level))
  end

  def self.roll_part_drop(part)
    return nil if part.drop_item_name.blank?

    chance = [part.drop_rate.to_i, PART_DROP_MIN_CHANCE].max
    rand(100) < chance ? part.drop_item_name : nil
  end

  def self.definitions_for(mob, enemy_level: nil)
    level = enemy_level || mob.effective_level
    definitions.select do |definition|
      definition.mob_name == mob.name && definition.available_for_level?(level)
    end
  end

  def self.definitions
    @definitions ||= load_definitions
  end

  def self.weighted_sample(candidates)
    weighted = candidates.flat_map do |candidate|
      [candidate] * [candidate.weight.to_i, 1].max
    end
    weighted.sample
  end

  def self.load_definitions
    path = Rails.root.join("db", "seeds", "mob_drops.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      DropDefinition.new(
        mob_name: row["mob"],
        item_name: row["item_name"],
        category: row["category"].presence || "drop",
        weight: row["weight"].presence&.to_i || 1,
        min_level: row["min_level"].presence&.to_i || 1,
        max_level: row["max_level"].presence&.to_i || 999
      )
    end
  end
end
