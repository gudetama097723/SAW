class Weapon < ApplicationRecord
  ONE_HANDED_TYPES = %w[片手直剣 細剣 短剣 棍 斧 片手棍 片手斧].freeze
  MAX_ENHANCEMENT_LEVEL = 10
  ENHANCEMENT_TYPES = {
    "S" => { attribute: :sharpness_level, name: "鋭さ", effect: "攻撃力 +4% / 部位破壊力 +0.5pt" },
    "Q" => { attribute: :quickness_level, name: "速さ", effect: "錬技倍率 +2% × 連撃係数" },
    "A" => { attribute: :accuracy_level, name: "正確さ", effect: "錬技命中率 +3pt / クリティカル率 +1pt" },
    "H" => { attribute: :heaviness_level, name: "重さ", effect: "部位破壊力 +4pt / 攻撃力 +1%" },
    "D" => { attribute: :durability_level, name: "丈夫さ", effect: "最大耐久値 +10% / 耐久消費率 -3%" }
  }.freeze
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

  ORIGINS = %w[starter shop crafted mob_drop boss_drop quest_reward].freeze
  EVOLVABLE_ORIGINS = %w[starter boss_drop quest_reward].freeze

  belongs_to :player, optional: true
  belongs_to :mob, optional: true
  belongs_to :player_base, optional: true

  before_save :unequip_excess_player_weapons, if: :being_equipped_by_player?

  validates :enhance_limit, :enhance_attempts,
    :sharpness_level, :quickness_level, :accuracy_level, :heaviness_level, :durability_level,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :enhancement_difficulty, numericality: { greater_than: 0 }
  validates :maintenance_level, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def stored?
    player_base_id.present?
  end

  def evolvable_origin?
    EVOLVABLE_ORIGINS.include?(origin)
  end

  def broken?
    durability.to_i <= 0
  end

  def craft_details
    JSON.parse(craft_data.presence || "{}")
  rescue JSON::ParserError
    {}
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
    origin == "starter"
  end

  def apply_durability_loss!(amount)
    adjusted_loss = amount.to_f * durability_cost_multiplier + durability_loss_remainder.to_f
    whole_loss = adjusted_loss.floor
    self.durability = durability.to_i - whole_loss
    self.durability_loss_remainder = adjusted_loss - whole_loss
  end

  def repair_cost
    missing = [effective_max_durability - durability.to_i, 0].max
    return 0 if missing <= 0

    missing_rate = missing.to_f / [effective_max_durability, 1].max
    estimated_price = [attack_power.to_i * 12 + effective_max_durability / 20 + enhancement_level.to_i * 120, 100].max
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
    return 0.0 unless effective_max_durability.positive?

    (durability.to_i.to_f / effective_max_durability).clamp(0.0, 1.0)
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
  enhancement_level.positive? ? "#{name} +#{enhancement_level}" : name
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
    # 強化段階が高いほど、また強化試行を使い切っていない(伸びしろが残っている)ほど高値になる。
    # 同じ+6でも試行を余して到達した個体の方が、試行を使い切った個体より高く売れる。
    enhancement_multiplier = 1.0 + enhancement_level.to_i * 0.05 + remaining_enhance_attempts * 0.03
    [(base * enhancement_multiplier * rarity_cost_multiplier / 2.0).floor, 1].max
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

  def enhancement_level
    directional_level = ENHANCEMENT_TYPES.sum { |_key, config| public_send(config[:attribute]).to_i }
    directional_level.positive? ? directional_level : super.to_i
  end

  def enhancement_level=(value)
    super(value.to_i.clamp(0, [enhance_limit.to_i, MAX_ENHANCEMENT_LEVEL].max))
  end

  def effective_attack_power
    [ base_effective_attack_power * durability_attack_multiplier, 1.0 ].max
  end

  def base_effective_attack_power
    attack_power.to_f * enhancement_attack_multiplier
  end

  def enhancement_attack_multiplier
    1.0 + enhancement_attack_percent / 100.0
  end

  def enhancement_attack_percent
    sharpness_level.to_i * 4.0 + heaviness_level.to_i
  end

  def enhancement_attack_bonus
    base_effective_attack_power - attack_power.to_f
  end

  def max_enhancement?
    enhance_attempts.to_i >= enhance_limit.to_i
  end

  def fully_enhanced?
    max_enhancement? && enhancement_level == enhance_limit.to_i
  end

  def remaining_enhance_attempts
    [ enhance_limit.to_i - enhance_attempts.to_i, 0 ].max
  end

  def enhancement_breakdown
    ENHANCEMENT_TYPES.filter_map do |_key, config|
      level = public_send(config[:attribute]).to_i
      "#{config[:name]} +#{level}" if level.positive?
    end.join("／").presence || "未強化"
  end

  def effective_max_durability
    (max_durability.to_i * (1.0 + durability_level.to_i * 0.10)).floor
  end

  def durability_cost_multiplier
    0.97**durability_level.to_i
  end

  def sword_skill_damage_multiplier(base_multiplier, hit_count)
    (base_multiplier.to_f * (1.0 + sword_skill_damage_bonus_percent(hit_count) / 100.0)).round
  end

  def sword_skill_damage_bonus_percent(hit_count)
    coefficient = { 1 => 1.0, 2 => 1.2, 3 => 1.4, 4 => 1.6 }.fetch([ hit_count.to_i, 1 ].max, 1.8)
    quickness_level.to_i * 2.0 * coefficient
  end

  def sword_skill_accuracy_bonus
    accuracy_level.to_i * 3
  end

  def sword_skill_critical_rate
    (effective_critical_rate + accuracy_level.to_i).clamp(0, 100)
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
    bonus = sharpness_level.to_i * 0.5 + heaviness_level.to_i * 4.0
    [ [ part_break_power.to_f + bonus, 0 ].max, 300 ].min
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

  private

  def being_equipped_by_player?
    player_id.present? && equipped? && (new_record? || will_save_change_to_equipped?)
  end

  def unequip_excess_player_weapons
    available_peer_slots = player.dual_wield? ? 1 : 0
    excess_ids = player.weapons
      .where(equipped: true)
      .where.not(id: id)
      .order(updated_at: :desc, id: :desc)
      .offset(available_peer_slots)
      .pluck(:id)
    player.weapons.where(id: excess_ids).update_all(equipped: false) if excess_ids.any?
  end
end
