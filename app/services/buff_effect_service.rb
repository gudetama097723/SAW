class BuffEffectService
  TIME_KEYS = %w[hp strength agility accuracy].freeze
  BATTLE_KEYS = %w[attack_percent defense_percent agility_percent accuracy_percent].freeze

  def self.time_effects(entity)
    parse_json(entity.buff_effects)
  end

  def self.battle_effects(entity)
    parse_json(entity.battle_effects)
  end

  def self.apply_time_buff!(player, key, effects, duration_minutes:)
    data = time_effects(player)
    data[key.to_s] = effects.stringify_keys.merge("remaining_minutes" => duration_minutes.to_i)
    player.buff_effects = data.to_json
  end

  def self.apply_battle_effect!(entity, key, effects, turns:)
    data = battle_effects(entity)
    data[key.to_s] = effects.stringify_keys.merge("remaining_turns" => turns.to_i)
    entity.battle_effects = data.to_json
  end

  def self.tick_time!(player, minutes)
    data = time_effects(player)
    data.keys.each do |key|
      data[key]["remaining_minutes"] = data[key]["remaining_minutes"].to_i - minutes.to_i
      data.delete(key) if data[key]["remaining_minutes"] <= 0
    end
    player.buff_effects = data.to_json
  end

  def self.tick_battle_turn!(entity)
    data = battle_effects(entity)
    data.keys.each do |key|
      data[key]["remaining_turns"] = data[key]["remaining_turns"].to_i - 1
      data.delete(key) if data[key]["remaining_turns"] <= 0
    end
    entity.battle_effects = data.to_json
  end

  def self.clear_battle_effects!(entity)
    entity.battle_effects = "{}" if entity.respond_to?(:battle_effects=)
  end

  def self.time_bonus(player, key)
    time_effects(player).values.sum { |effect| effect[key.to_s].to_i }
  end

  def self.battle_percent(entity, key)
    battle_effects(entity).values.sum { |effect| effect[key.to_s].to_f }
  end

  def self.sure_hit?(entity)
    battle_effects(entity).values.any? { |effect| effect["sure_hit"] == true || effect["sure_hit"].to_s == "true" }
  end

  def self.accuracy_modifier(entity)
    time = entity.respond_to?(:buff_effects) ? time_bonus(entity, "accuracy") : 0
    time + battle_percent(entity, "accuracy_percent")
  end

  def self.attack_multiplier(entity)
    percent_multiplier(battle_percent(entity, "attack_percent"))
  end

  def self.defense_damage_taken_multiplier(entity)
    percent_multiplier(-battle_percent(entity, "defense_percent"))
  end

  def self.agility_multiplier(entity)
    percent_multiplier(battle_percent(entity, "agility_percent"))
  end

  def self.percent_multiplier(percent)
    [1.0 + percent.to_f / 100.0, 0.05].max
  end

  def self.parse_json(value)
    JSON.parse(value.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
