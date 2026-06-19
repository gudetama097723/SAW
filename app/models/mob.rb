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
end

