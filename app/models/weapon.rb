class Weapon < ApplicationRecord
  MAX_ENHANCEMENT_LEVEL = 10
  belongs_to :player, optional: true
  belongs_to :mob, optional: true

  def broken?
    return false if starter_weapon?

    durability.to_i <= 0
  end

  def starter_weapon?
    name == "スモールソード"
  end

  def apply_durability_loss!(amount)
    self.durability = durability.to_i - amount.to_i
    self.durability = 1 if starter_weapon? && durability.to_i < 1
  end

  def repair_cost
    missing = [max_durability.to_i - durability.to_i, 0].max
    missing * rarity_cost_multiplier
  end

  def sell_price
    return 0 if starter_weapon?

    base = attack_power.to_i * 4
    durability_rate = max_durability.to_i.positive? ? durability.to_i.to_f / max_durability.to_i : 0.5
    [(base * durability_rate * rarity_cost_multiplier / 2.0).floor, 1].max
  end

  def attack_attribute_list
    attack_attributes.to_s.split(/[|,、]/).map { |attribute| AttackAttribute.normalize(attribute) }.presence || ["斬撃"]
  end

  def primary_attack_attribute
    attack_attribute_list.first
  end

  def matches_attack_attribute?(attribute)
    attack_attribute_list.include?(AttackAttribute.normalize(attribute))
  end

  def enhancement_level=(value)
    super(value.to_i.clamp(0, MAX_ENHANCEMENT_LEVEL))
  end

  def effective_attack_power
    attack_power.to_i + enhancement_attack_bonus
  end

  def enhancement_attack_bonus
    (attack_power.to_i * enhancement_level.to_i * 0.06).floor
  end

  def max_enhancement?
    enhancement_level.to_i >= MAX_ENHANCEMENT_LEVEL
  end

  def enhancement_requirements
    JSON.parse(enhancement_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def effective_critical_rate
    [[critical_rate.to_i, 0].max, 100].min
  end

  def effective_part_break_power
    [[part_break_power.to_i, 0].max, 300].min
  end

  def rarity_cost_multiplier
    {
      "common" => 2,
      "uncommon" => 3,
      "rare" => 5,
      "epic" => 8,
      "legendary" => 13
    }.fetch(rarity, 2)
  end
end

