class Skill < ApplicationRecord
  SKILL_MODS_KEY = "skill_mods"

  belongs_to :player

  def gain_skill_exp!(amount, growth_scale:)
    before = proficiency.to_i
    self.skill_exp = skill_exp.to_i + amount.to_i
    self.proficiency = proficiency_from_exp(skill_exp, growth_scale)
    awarded_slot = false
    if weapon_skill? && before < 1000 && proficiency.to_i >= 1000 && !capstone_slot_awarded?
      self.capstone_slot_awarded = true
      player.increment!(:skill_slot_bonus)
      awarded_slot = true
    end
    save!
    awarded_slot
  end

  def sword_skill_level(skill_key)
    sword_skill_level_data.dig(skill_key.to_s, "level").to_i.clamp(1, 100)
  end

  def gain_sword_skill_exp!(skill_key, amount)
    levels = sword_skill_level_data
    key = skill_key.to_s
    current_exp = levels.dig(key, "exp").to_i + amount.to_i
    current_level = [1 + Math.sqrt(current_exp / 12.0).floor, 100].min
    levels[key] = { "level" => current_level, "exp" => current_exp }
    self.sword_skill_levels = levels.to_json
    save!
    current_level
  end

  def sword_skill_level_data
    raw = JSON.parse(sword_skill_levels.presence || "{}")
    raw.transform_values { |value| value.is_a?(Hash) ? value : { "level" => value.to_i, "exp" => 0 } }
  rescue JSON::ParserError
    {}
  end

  def learn_condition
    JSON.parse(learn_condition_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def skill_mod_data
    value = learn_condition[SKILL_MODS_KEY]
    value.is_a?(Hash) ? value : {}
  end

  def skill_mod_rank(mod_key)
    skill_mod_data[mod_key.to_s].to_i
  end

  def skill_mod_points_earned
    return 0 unless weapon_skill?

    (proficiency.to_i.clamp(0, 1000) / 50).floor
  end

  def skill_mod_points_spent
    SkillModCatalog.all(name).sum do |mod|
      mod.total_cost_for_rank(skill_mod_rank(mod.key))
    end
  end

  def skill_mod_points_remaining
    [skill_mod_points_earned - skill_mod_points_spent, 0].max
  end

  def can_learn_skill_mod?(mod_key)
    mod = SkillModCatalog.find(mod_key)
    return false unless mod && mod.skill_name == name

    current_rank = skill_mod_rank(mod.key)
    current_rank < mod.max_rank && skill_mod_points_remaining >= mod.next_cost(current_rank)
  end

  def learn_skill_mod!(mod_key)
    mod = SkillModCatalog.find(mod_key)
    raise ArgumentError, "unknown skill mod" unless mod && mod.skill_name == name
    raise ArgumentError, "skill mod cannot be learned" unless can_learn_skill_mod?(mod.key)

    data = learn_condition
    mods = data[SKILL_MODS_KEY].is_a?(Hash) ? data[SKILL_MODS_KEY] : {}
    mods[mod.key] = skill_mod_rank(mod.key) + 1
    data[SKILL_MODS_KEY] = mods
    self.learn_condition_data = data.to_json
    save!
    mods[mod.key]
  end

  def weapon_skill?
    self[:weapon_skill] == true || skill_category == "weapon"
  end

  def proficiency_from_exp(exp, growth_scale)
    scale = [growth_scale.to_i, 1].max
    raw = 1000 * (1 - Math.exp(-exp.to_i / scale.to_f))
    # raw は指数関数の漸近曲線のため、浮動小数点上は現実的なexp量では999までしか到達せず、
    # 文字通りの1000には天文学的なexpが必要になってしまう。999到達をもって実質カンスト扱いにする。
    value = raw >= 999 ? 1000 : raw.floor
    value.clamp(0, 1000)
  end
end
