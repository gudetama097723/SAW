class Weapon < ApplicationRecord
  ONE_HANDED_TYPES = %w[片手直剣 細剣 短剣 棍 斧 片手棍 片手斧].freeze
  MAX_ENHANCEMENT_LEVEL = 10
  MAJOR_DAMAGE_DURABILITY = -40
  LOST_DURABILITY_THRESHOLD = -50

  BROKEN_REPAIR_MATERIALS = {
    "蒼狼の牙剣" => { "狼王の牙" => 1 },
    "錆びたショートソード" => { "コボルドの牙" => 1 },
    "斥候のショートソード" => { "コボルドの牙" => 1 }
  }.freeze

  DEFAULT_REPAIR_MATERIALS_BY_TYPE = {
    "片手直剣" => { "硬い甲殻" => 1 },
    "細剣" => { "薄羽蜂の針" => 1 },
    "棍" => { "蟹の脚殻" => 1 },
    "斧" => { "蟹の脚殻" => 1 }
  }.freeze

  belongs_to :player, optional: true
  belongs_to :mob, optional: true
  belongs_to :player_base, optional: true

  def stored?
    player_base_id.present?
  end

  def broken?
    durability.to_i <= 0
  end

  def one_handed?
    ONE_HANDED_TYPES.include?(weapon_type)
  end

  def major_damage?
    durability.to_i <= MAJOR_DAMAGE_DURABILITY
  end

  def lost_by_durability?
    durability.to_i < LOST_DURABILITY_THRESHOLD
  end

  def starter_weapon?
    StarterWeaponCatalog.all.any? { |choice| choice.name == name }
  end

  def apply_durability_loss!(amount)
    self.durability = durability.to_i - amount.to_i
  end

  def repair_cost
    missing = [max_durability.to_i - durability.to_i, 0].max
    return 0 if missing <= 0

    missing_rate = missing.to_f / [max_durability.to_i, 1].max
    estimated_price = [attack_power.to_i * 12 + max_durability.to_i / 20 + enhancement_level.to_i * 120, 100].max
    full_repair_cost = (estimated_price * rarity_cost_multiplier * 0.5).ceil
    [(full_repair_cost * missing_rate * repair_condition_cost_multiplier).ceil, 1].max
  end

  def repair_condition_cost_multiplier
    return 3.0 if major_damage?
    return 2.5 if broken?

    rate = durability_rate
    return 1.8 if rate <= 0.10
    return 1.4 if rate <= 0.25
    return 1.15 if rate <= 0.50

    1.0
  end

  def repair_materials_required
    return {} unless broken?

    BROKEN_REPAIR_MATERIALS.fetch(name) do
      DEFAULT_REPAIR_MATERIALS_BY_TYPE.fetch(weapon_type, { "硬い甲殻" => 1 })
    end
  end

  def repair_materials_text
    return "不要" if repair_materials_required.empty?

    repair_materials_required.map { |name, count| "#{name} ×#{count}" }.join("、")
  end

  def durability_rate
    return 0.0 unless max_durability.to_i.positive?

    (durability.to_i.to_f / max_durability.to_i).clamp(0.0, 1.0)
  end

  def durability_percent
    (durability_rate * 100).floor
  end

  def durability_condition_label
    return "大破" if major_damage?
    return "破損" if broken?

    rate = durability_rate
    return "破損寸前" if rate <= 0.10
    return "損傷" if rate <= 0.25
    return "消耗" if rate <= 0.50

    "良好"
  end

  def durability_attack_multiplier
    return 0.10 if broken?

    rate = durability_rate
    return 0.50 if rate <= 0.10
    return 0.70 if rate <= 0.25
    return 0.85 if rate <= 0.50

    1.0
  end

def display_name
  enhancement_level.to_i.positive? ? "#{name} +#{enhancement_level}" : name
end

def protected_item?
  equipped? || favorite? || protected_from_death_penalty? || unique_item? || !discardable?
end

def sellable_by_player?
  !equipped? && !favorite? && discardable? && !protected_from_death_penalty?
end

def discardable_by_player?
  !equipped? && !favorite? && discardable? && !unique_item?
end

def stat_attack_power(player)
  strength_part = player.effective_strength * strength_ratio.to_i / 100.0
  agility_part = player.effective_agility * agility_ratio.to_i / 100.0
  strength_part + agility_part
end

def sell_price
    base = effective_attack_power.to_i * 4
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
    [(base_effective_attack_power * durability_attack_multiplier).ceil, 1].max
  end

  def base_effective_attack_power
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

  def status_resistance
    JSON.parse(status_resistance_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def status_resistance_bonus(status)
    status_resistance[status.to_s].to_i
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


