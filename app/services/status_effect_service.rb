class StatusEffectService
  STATUSES = %w[poison paralysis sleep burn curse].freeze
  RECOVERABLE_STATUSES = %w[poison paralysis sleep burn].freeze
  LABELS = {
    "poison" => "毒",
    "paralysis" => "麻痺",
    "sleep" => "睡眠",
    "burn" => "火傷",
    "curse" => "呪い"
  }.freeze
  DEFAULT_THRESHOLD = 100
  VALUE_DECAY_PER_MINUTE = 0.2

  def self.labels_for(entity)
    effect_data(entity).keys.filter_map { |key| LABELS[key.to_s] if active?(entity, key) }
  end

  def self.active?(entity, status)
    value = effect_data(entity)[status.to_s]
    case value
    when Hash
      value["active"] != false
    else
      value.present? && value != false
    end
  end

  def self.accumulate!(entity, status, amount)
    key = status.to_s
    return unless STATUSES.include?(key)

    values = value_data(entity)
    values[key] = values[key].to_f + amount.to_f
    write_value_data(entity, values)
    activate!(entity, key) if values[key].to_f >= threshold_for(entity, key)
  end

  def self.activate!(entity, status)
    key = status.to_s
    effects = effect_data(entity)
    effects[key] =
      if key == "paralysis"
        { "active" => true, "turns" => rand(3..5) }
      else
        true
      end
    write_effect_data(entity, effects)
    clamp_hp_to_max!(entity) if key == "curse"
  end

  def self.cure!(entity, status)
    effects = effect_data(entity)
    effects.delete(status.to_s)
    write_effect_data(entity, effects)
    clamp_hp_to_max!(entity)
  end

  def self.cure_recoverable!(entity)
    effects = effect_data(entity)
    RECOVERABLE_STATUSES.each { |status| effects.delete(status) }
    write_effect_data(entity, effects)
  end

  def self.decay_values!(entity, minutes)
    amount = minutes.to_i * VALUE_DECAY_PER_MINUTE
    return if amount <= 0

    values = value_data(entity)
    values.keys.each do |key|
      values[key] = [values[key].to_f - amount, 0].max
      values.delete(key) if values[key].zero?
    end
    write_value_data(entity, values)
  end

  def self.apply_time_passage!(entity, minutes)
    apply_poison_damage!(entity, max_hp_for(entity) * 0.01 * minutes.to_i) if active?(entity, "poison")
    decay_values!(entity, minutes)
  end

  def self.apply_battle_turn_start!(entity)
    return "" unless active?(entity, "poison")

    damage = apply_poison_damage!(entity, max_hp_for(entity) * 0.05)
    damage.positive? ? "#{name_for(entity)}は毒で#{damage}ダメージを受けた。" : ""
  end

  def self.action_blocked_message!(entity)
    if active?(entity, "sleep")
      return "#{name_for(entity)}は眠っていて動けない。"
    end

    return unless active?(entity, "paralysis")

    effects = effect_data(entity)
    state = effects["paralysis"]
    turns = state.is_a?(Hash) ? state["turns"].to_i : 1
    turns -= 1
    if turns <= 0
      effects.delete("paralysis")
      write_effect_data(entity, effects)
      "#{name_for(entity)}の麻痺が解けた。"
    else
      effects["paralysis"] = { "active" => true, "turns" => turns }
      write_effect_data(entity, effects)
      "#{name_for(entity)}は麻痺して動けない。"
    end
  end

  def self.damage_dealt_multiplier(entity)
    active?(entity, "burn") ? 0.8 : 1.0
  end

  def self.damage_taken_multiplier(entity)
    active?(entity, "burn") ? 1.2 : 1.0
  end

  def self.sleeping_critical!(entity)
    return false unless active?(entity, "sleep")

    cure!(entity, "sleep")
    true
  end

  def self.max_hp_multiplier(entity)
    active?(entity, "curse") ? 0.7 : 1.0
  end

  def self.value_data(entity)
    parse_json(entity.status_values)
  end

  def self.effect_data(entity)
    return {} unless entity.respond_to?(:status_effects)

    parse_json(entity.status_effects)
  end

  def self.write_value_data(entity, data)
    entity.status_values = data.to_json
  end

  def self.write_effect_data(entity, data)
    entity.status_effects = data.to_json
  end

  def self.threshold_for(entity, status)
    if entity.respond_to?(:status_accumulation_limit)
      entity.status_accumulation_limit(status)
    else
      DEFAULT_THRESHOLD
    end
  end

  def self.apply_poison_damage!(entity, raw_damage)
    damage = [raw_damage.ceil, 1].max
    set_hp(entity, hp_for(entity) - damage)
    damage
  end

  def self.clamp_hp_to_max!(entity)
    set_hp(entity, [hp_for(entity), max_hp_for(entity)].min)
  end

  def self.hp_for(entity)
    entity.respond_to?(:enemy_hp) ? entity.enemy_hp.to_i : entity.hp.to_i
  end

  def self.set_hp(entity, value)
    value = [value.to_i, 0].max
    entity.respond_to?(:enemy_hp=) ? entity.enemy_hp = value : entity.hp = value
  end

  def self.max_hp_for(entity)
    entity.respond_to?(:effective_max_hp) ? entity.effective_max_hp.to_i : entity.max_hp.to_i
  end

  def self.name_for(entity)
    entity.respond_to?(:mob) ? entity.mob.name : entity.name
  end

  def self.parse_json(value)
    JSON.parse(value.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
