SEED_DIR = Rails.root.join("db", "seeds")

def seed_rows(file_name)
  SimpleCsv.foreach(SEED_DIR.join(file_name)) do |row|
    yield row
  end
end

def to_bool(value)
  value.to_s.strip.downcase == "true"
end

def to_int(value)
  value.present? ? value.to_i : nil
end

locations = {}
seed_rows("locations.csv") do |row|
  location = Location.find_or_create_by!(name: row["name"])
  location.update!(
    floor: to_int(row["floor"]),
    danger_level: to_int(row["danger_level"]),
    safe_area: to_bool(row["safe_area"])
  )
  locations[location.name] = location
end

seed_rows("routes.csv") do |row|
  from_location = locations.fetch(row["from"])
  to_location = locations.fetch(row["to"])
  route = Route.find_or_create_by!(from_location: from_location, to_location: to_location)
  route.update!(
    name: row["name"],
    travel_time: to_int(row["travel_time"]),
    danger_level: to_int(row["danger_level"]),
    distance: to_int(row["distance"]) || 100,
    mapping_difficulty: row["mapping_difficulty"].presence || 1.0
  )
end

routes = Route.all.index_by(&:name)
seed_rows("field_areas.csv") do |row|
  route = routes.fetch(row["route"])
  area = FieldArea.find_or_initialize_by(route: route, name: row["name"])
  area.update!(
    start_distance: to_int(row["start_distance"]),
    end_distance: to_int(row["end_distance"]),
    encounter_rate: to_int(row["encounter_rate"]) || 30,
    rest_safety: to_int(row["rest_safety"]) || 70,
    description: row["description"].presence
  )
end

town = locations.fetch("はじまりの街")
demo_user = User.find_or_initialize_by(username: "kirito")
demo_user.password = "password" if demo_user.new_record?
demo_user.save!

player = demo_user.player || Player.find_by(name: "キリト") || Player.new
player.name = "キリト"
player.user = demo_user
if player.new_record?
  player.hp = 100
  player.col = 0
  player.floor = 1
  player.location = town
  player.current_time = 480
end

player.update!(
  location: town,
  current_time: 480,
  level: player.level.presence || 1,
  exp: player.exp.presence || 0,
  max_hp: [player.max_hp.to_i, Player.max_hp_for_level(player.level.presence || 1)].max,
  strength: player.strength.presence || 1,
  agility: player.agility.presence || 1,
  stat_points: player.stat_points.presence || 0,
  skill_slots: player[:skill_slots].presence || 2
)

seed_rows("player_weapons.csv") do |row|
  weapon = Weapon.find_or_initialize_by(player: player, name: row["name"])
  weapon.update!(
    weapon_type: row["weapon_type"],
    rarity: row["rarity"],
    attack_power: to_int(row["attack_power"]),
    durability: to_int(row["durability"]),
    max_durability: to_int(row["max_durability"]),
    hp_bonus: to_int(row["hp_bonus"]),
    strength_bonus: to_int(row["strength_bonus"]),
    agility_bonus: to_int(row["agility_bonus"]),
    critical_rate: to_int(row["critical_rate"]),
    part_break_power: to_int(row["part_break_power"]) || 100,
    equipped: to_bool(row["equipped"])
  )
end

seed_rows("player_armors.csv") do |row|
  armor = Armor.find_or_initialize_by(player: player, name: row["name"])
  armor.update!(
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

seed_rows("player_skills.csv") do |row|
  skill = Skill.find_or_create_by!(player: player, name: row["name"]) do |new_skill|
    new_skill.proficiency = to_int(row["proficiency"]) || 0
    new_skill.skill_exp = to_int(row["skill_exp"]) || 0 if new_skill.has_attribute?(:skill_exp)
  end
  attributes = { proficiency: [skill.proficiency.to_i, to_int(row["proficiency"]) || 0].max }
  attributes[:skill_exp] = [skill.skill_exp.to_i, to_int(row["skill_exp"]) || 0].max if skill.has_attribute?(:skill_exp)
  skill.update!(attributes)
end

mobs = {}
seed_rows("mobs.csv") do |row|
  mob = Mob.find_or_create_by!(name: row["name"])
  mob.update!(
    hp: to_int(row["hp"]),
    atk: to_int(row["atk"]),
    rarity: row["rarity"],
    level: to_int(row["level"]),
    agility: to_int(row["agility"]),
    durability: to_int(row["durability"]),
    exp_reward: to_int(row["exp_reward"]),
    col_min: to_int(row["col_min"]) || 1,
    col_max: to_int(row["col_max"]) || 3
  )
  mobs[mob.name] = mob
end

seed_rows("mob_parts.csv") do |row|
  mob = mobs.fetch(row["mob"])
  part = MobPart.find_or_create_by!(mob: mob, name: row["name"])
  part.update!(
    damage_multiplier: to_int(row["damage_multiplier"]),
    weakness: to_bool(row["weakness"]),
    max_durability: to_int(row["max_durability"]),
    break_effect: row["break_effect"].presence,
    drop_item_name: row["drop_item_name"].presence,
    drop_rate: to_int(row["drop_rate"]) || 0
  )
end

seed_rows("mob_weapons.csv") do |row|
  mob = mobs.fetch(row["mob"])
  weapon = Weapon.find_or_initialize_by(mob: mob, name: row["name"])
  weapon.update!(
    weapon_type: row["weapon_type"],
    rarity: row["rarity"],
    attack_power: to_int(row["attack_power"]),
    durability: to_int(row["durability"]),
    max_durability: to_int(row["max_durability"]),
    hp_bonus: to_int(row["hp_bonus"]),
    strength_bonus: to_int(row["strength_bonus"]),
    agility_bonus: to_int(row["agility_bonus"]),
    critical_rate: to_int(row["critical_rate"]),
    part_break_power: to_int(row["part_break_power"]) || 100,
    drop_rate: to_int(row["drop_rate"])
  )
end
