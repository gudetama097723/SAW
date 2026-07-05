class Mob < ApplicationRecord
  has_many :mob_parts, dependent: :destroy
  has_many :weapons, dependent: :destroy
  belongs_to :field_area, optional: true
  belongs_to :route, optional: true

  def equipped_weapon
    weapons.first
  end

  def effective_level
    [level.to_i, 1].max
  end

  def hp_for_level(enemy_level)
    stat_for_level(hp, growth_value(:hp_growth), enemy_level, minimum: 1)
  end

  def atk_for_level(enemy_level)
    stat_for_level(atk, growth_value(:atk_growth), enemy_level, minimum: 1)
  end

  def agility_for_level(enemy_level)
    stat_for_level(agility, growth_value(:agility_growth), enemy_level, minimum: 1)
  end

  def durability_for_level(enemy_level)
    stat_for_level(durability, growth_value(:durability_growth), enemy_level, minimum: 0)
  end

  def col_min_for_level(enemy_level)
    stat_for_level(col_min, growth_value(:col_growth), enemy_level, minimum: 1)
  end

  def col_max_for_level(enemy_level)
    stat_for_level(col_max, growth_value(:col_growth), enemy_level, minimum: 1)
  end

  def effective_agility
    [agility.to_i, 1].max
  end

  def effective_flee_rate
    flee_rate.to_i.clamp(0, 100)
  end

  def weak_to_attribute?(attribute)
    weak_attack_attribute.present? && AttackAttribute.normalize(weak_attack_attribute) == AttackAttribute.normalize(attribute)
  end

  def boss?
    boss_type != "normal"
  end

  def field_boss?
    boss_type == "field_boss"
  end

  def level_based?
    true
  end

  def reward
    JSON.parse(reward_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def status_thresholds
    JSON.parse(status_threshold_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def status_accumulation_limit(status)
    status_thresholds.fetch(status.to_s, default_status_threshold(status)).to_i
  end

  def status_attacks
    configured = JSON.parse(status_attack_data.presence || "{}")
    return configured if configured.present?

    default_status_attacks
  rescue JSON::ParserError
    default_status_attacks
  end

  def default_status_threshold(status)
    boss? ? 160 : 100
  end

  def default_status_attacks
    case name
    when "スライム"
      { "poison" => 12 }
    when "変異スライム"
      { "poison" => 25 }
    when "フォレストワスプ"
      { "paralysis" => 25 }
    when "蒼狼フェンリル"
      { "curse" => 18 }
    else
      {}
    end
  end

  private

  def stat_for_level(base, growth, enemy_level, minimum:)
    level = [enemy_level.to_i, 1].max
    [base.to_i + (growth.to_i * (level - 1)), minimum].max
  end

  def growth_value(column)
    has_attribute?(column) ? self[column].to_i : 0
  end
end

