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
end

