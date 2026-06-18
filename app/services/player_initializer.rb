class PlayerInitializer
  def self.create_for_user!(user)
    town = Location.find_by(name: "はじまりの街") || Location.first
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

    create_initial_weapons!(player)
    create_initial_armors!(player)
    create_initial_skills!(player)
    player
  end

  def self.create_initial_weapons!(player)
    seed_rows("player_weapons.csv") do |row|
      player.weapons.create!(
        name: row["name"],
        weapon_type: row["weapon_type"],
        rarity: row["rarity"],
        attack_power: to_int(row["attack_power"]),
        durability: to_int(row["durability"]),
        max_durability: to_int(row["max_durability"]),
        hp_bonus: to_int(row["hp_bonus"]),
        strength_bonus: to_int(row["strength_bonus"]),
        agility_bonus: to_int(row["agility_bonus"]),
        critical_rate: to_int(row["critical_rate"]),
        equipped: to_bool(row["equipped"])
      )
    end
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
        equipped: to_bool(row["equipped"])
      )
    end
  end

  def self.create_initial_skills!(player)
    seed_rows("player_skills.csv") do |row|
      player.skills.create!(
        name: row["name"],
        proficiency: to_int(row["proficiency"]) || 0,
        skill_exp: to_int(row["skill_exp"]) || 0
      )
    end
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
