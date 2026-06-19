class Skill < ApplicationRecord
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
    sword_skill_level_data[skill_key.to_s].to_i.clamp(1, 100)
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

  def weapon_skill?
    self[:weapon_skill] == true || skill_category == "weapon"
  end

  def proficiency_from_exp(exp, growth_scale)
    scale = [growth_scale.to_i, 1].max
    (1000 * (1 - Math.exp(-exp.to_i / scale.to_f))).floor.clamp(0, 1000)
  end
end

