class PlayerInitializer
  def self.create_for_user!(user)
    town = Location.find_by(name: "ヴィーゲンブルク") || Location.first
    player = user.create_player!(
      name: user.username,
      hp: 100,
      col: 0,
      floor: 1,
      location: town,
      current_time: 480,
      level: 1,
      exp: 0,
      max_hp: Player.max_hp_for_level(1),
      strength: 1,
      agility: 1,
      stat_points: 0,
      skill_slots: 2,
      skill_slot_bonus: 0
    )

    create_initial_armors!(player)
    player
  end

  def self.choose_initial_weapon!(player, choice)
    return false if choice.blank? || player.weapons.exists?

    player.transaction do
      create_initial_weapon!(player, choice)
      create_initial_weapon_skill!(player, choice.weapon_type)
    end
    true
  end

  def self.create_initial_weapon!(player, choice)
    player.weapons.create!(
      name: choice.name,
      weapon_type: choice.weapon_type,
      rarity: choice.rarity,
      attack_power: choice.attack_power,
      durability: choice.durability,
      max_durability: choice.max_durability,
      hp_bonus: choice.hp_bonus,
      strength_bonus: choice.strength_bonus,
      agility_bonus: choice.agility_bonus,
      critical_rate: choice.critical_rate,
      part_break_power: choice.part_break_power,
      attack_attributes: choice.attack_attributes,
      enhancement_level: 0,
      enhance_limit: 10,
      enhancement_difficulty: 0.7,
      equipped: true,
      weight: choice.weight,
      strength_ratio: choice.strength_ratio,
      agility_ratio: choice.agility_ratio,
      description: choice.description,
      discardable: false,
      protected_from_death_penalty: true
    )
  end

  def self.create_initial_armors!(player)
    seed_rows("player_armors.csv") do |row|
      player.armors.create!(
        name: row["name"],
        armor_type: row["armor_type"],
        slot: row["slot"],
        rarity: row["rarity"],
        defense: to_int(row["defense"]),
        weight: to_int(row["weight"]),
        hp_bonus: to_int(row["hp_bonus"]),
        strength_bonus: to_int(row["strength_bonus"]),
        agility_bonus: to_int(row["agility_bonus"]),
        durability: to_int(row["durability"]),
        max_durability: to_int(row["max_durability"]),
        equipped: to_bool(row["equipped"])
      )
    end
  end

  def self.create_initial_weapon_skill!(player, weapon_type)
    return if player.skills.exists?(name: weapon_type)

    player.skills.create!(
      name: weapon_type,
      proficiency: 0,
      skill_exp: 0,
      skill_category: "weapon",
      weapon_skill: true
    )
  end

  def self.seed_rows(file_name, &block)
    SimpleCsv.foreach(Rails.root.join("db", "seeds", file_name), &block)
  end

  def self.to_bool(value)
    value.to_s.strip.downcase == "true"
  end

  def self.to_int(value)
    value.present? ? value.to_i : nil
  end
end
