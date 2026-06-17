class Player < ApplicationRecord
  has_many :skills, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :battles, dependent: :destroy
  has_many :rests, dependent: :destroy
  has_many :weapons, dependent: :destroy
  has_many :armors, dependent: :destroy
  belongs_to :location, optional: true

  def equipped_weapons
    weapons.where(equipped: true)
  end

  def equipped_weapon
    equipped_weapons.first
  end

  def dual_wield?
    skills.exists?(name: "二刀流")
  end

  def equipped_armors
    armors.where(equipped: true)
  end

  def armor_for(slot)
    equipped_armors.find_by(slot: slot)
  end

  def effective_max_hp
    max_hp.to_i + equipped_weapons.sum(:hp_bonus).to_i + equipped_armors.sum(:hp_bonus).to_i
  end

  def effective_strength
    strength.to_i + equipped_weapons.sum(:strength_bonus).to_i + equipped_armors.sum(:strength_bonus).to_i
  end

  def effective_agility
    base_agility = agility.to_i + equipped_weapons.sum(:agility_bonus).to_i + equipped_armors.sum(:agility_bonus).to_i
    [base_agility - equipment_weight_penalty, 1].max
  end

  def equipment_weight
    equipped_armors.sum(:weight).to_i
  end

  def equipment_weight_penalty
    [equipment_weight - effective_strength, 0].max
  end

  def damage_cut
    equipped_armors.sum(:defense).to_i
  end

  def used_skill_slots
    skills.exists?(name: "片手剣") ? 1 : 0
  end

  def remaining_skill_slots
    [skill_slots.to_i - used_skill_slots, 0].max
  end

  def exp_to_next_level
    30 + ((effective_level - 1) * 20)
  end

  def effective_level
    [level.to_i, 1].max
  end

  def gain_exp!(amount)
    self.exp = exp.to_i + amount.to_i

    while exp >= exp_to_next_level
      self.exp -= exp_to_next_level
      self.level = level.to_i + 1
      self.max_hp = max_hp.to_i + 10
      self.stat_points = stat_points.to_i + 3
      self.skill_slots = skill_slots.to_i + 1 if (level % 5).zero?
    end

    save!
  end
end
