class Weapon < ApplicationRecord
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
