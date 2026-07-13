class CraftedWeaponStatGenerator
  QUALITY_POINTS = [
    [ 0, 0.60, 1.05 ], [ 100, 0.65, 1.10 ], [ 500, 0.80, 1.20 ],
    [ 750, 0.88, 1.28 ], [ 1000, 0.95, 1.35 ]
  ].freeze

  def self.call(proficiency:, ore:, monster_material:, support_material:, template:, rng: Random)
    minimum, maximum = quality_range(proficiency)
    qualities = %i[attack durability weight enhance].to_h do |target|
      min = minimum
      max = maximum
      if support_material&.target_quality == target.to_s
        min += support_material.min_quality_bonus
        max += support_material.max_quality_bonus
      end
      [ target, rng.rand(min..max).round(4) ]
    end

    attack = ore.craft_attack * template.attack_multiplier * qualities[:attack] * monster_material.attack_modifier
    maximum_durability = ore.craft_durability * template.durability_multiplier * qualities[:durability] * monster_material.durability_modifier
    weight = ore.craft_weight * template.weight_multiplier * monster_material.weight_modifier / qualities[:weight]
    enhance_limit = ore.craft_enhance_limit * template.enhance_multiplier * qualities[:enhance]

    {
      attack_power: [ attack.round, 1 ].max,
      max_durability: [ maximum_durability.round, 1 ].max,
      durability: [ maximum_durability.round, 1 ].max,
      weight: [ weight.round, 1 ].max,
      enhance_limit: [ enhance_limit.floor, 1 ].max,
      part_break_power: [ 100 + monster_material.break_modifier, 0 ].max,
      qualities: qualities
    }
  end

  def self.quality_range(proficiency)
    value = proficiency.to_i.clamp(0, 1000)
    lower, upper = QUALITY_POINTS.each_cons(2).find { |left, right| value.between?(left[0], right[0]) }
    return QUALITY_POINTS.last.drop(1) unless lower && upper

    progress = (value - lower[0]).to_f / (upper[0] - lower[0])
    [ lower[1] + (upper[1] - lower[1]) * progress, lower[2] + (upper[2] - lower[2]) * progress ]
  end
end
