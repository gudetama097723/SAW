class Mob < ApplicationRecord
  has_many :mob_parts, dependent: :destroy
  has_many :weapons, dependent: :destroy

  def equipped_weapon
    weapons.first
  end

  def effective_level
    [level.to_i, 1].max
  end

  def effective_agility
    [agility.to_i, 1].max
  end
end
