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
    safe_area: to_bool(row["safe_area"]),
    weather: row["weather"].presence || "clear",
    environment: row["environment"].presence || "normal"
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
    required_mapping_to_enter_next: to_int(row["required_mapping_to_enter_next"]) || 30,
    required_mapping_to_reach_town: to_int(row["required_mapping_to_reach_town"]) || 0,
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

player.obtain_key_item!(
  name: "はじまりの街の通行証",
  description: "はじまりの街で正式なプレイヤーとして登録された証。",
  category: "story",
  unique_key: "beginning_town_pass"
)
player.obtain_key_item!(
  name: "古びた地図",
  description: "第一層の古い地図。ところどころ破れている。",
  category: "map",
  unique_key: "first_floor_old_map"
)
player.obtain_key_item!(
  name: "老剣士の紹介状",
  description: "老剣士が信頼できる相手へ向けて書いた紹介状。",
  category: "npc",
  unique_key: "old_swordsman_letter"
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
attack_attributes: row["attack_attributes"].presence || "斬撃",
enhancement_level: to_int(row["enhancement_level"]) || 0,
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
    flee_rate: to_int(row["flee_rate"]) || 0,
    col_min: to_int(row["col_min"]) || 1,
    col_max: to_int(row["col_max"]) || 3
  )
  mobs[mob.name] = mob
end

mobs.merge!(Mob.where.not(name: mobs.keys).index_by(&:name))

seed_rows("mob_parts.csv") do |row|
  mob = mobs.fetch(row["mob"])
  part = MobPart.find_or_create_by!(mob: mob, name: row["name"])
  part.update!(
    damage_multiplier: to_int(row["damage_multiplier"]),
    weakness: to_bool(row["weakness"]),
    max_durability: to_int(row["max_durability"]),
    break_effect: row["break_effect"].presence,
    drop_item_name: row["drop_item_name"].presence,
drop_rate: to_int(row["drop_rate"]) || 0,
  weak_attack_attribute: row["weak_attack_attribute"].presence
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
attack_attributes: row["attack_attributes"].presence || "斬撃",
enhancement_level: to_int(row["enhancement_level"]) || 0,
drop_rate: to_int(row["drop_rate"])
  )
end

seed_rows("boss_mobs.csv") do |row|
  route = routes.fetch(row["route"])
  area = row["field_area"].present? ? route.field_areas.find_by!(name: row["field_area"]) : nil
  mob = Mob.find_or_create_by!(name: row["name"])
  mob.update!(
    hp: to_int(row["hp"]),
    atk: to_int(row["atk"]),
    rarity: row["rarity"],
    level: to_int(row["level"]),
    agility: to_int(row["agility"]),
    durability: to_int(row["durability"]),
    exp_reward: to_int(row["exp_reward"]),
    flee_rate: to_int(row["flee_rate"]) || 0,
    col_min: to_int(row["col_min"]) || 1,
    col_max: to_int(row["col_max"]) || 3,
    route: route,
    field_area: area,
    boss_type: row["boss_type"],
    reward_data: row["reward_data"].presence || "{}"
  )
end

seed_rows("treasure_chests.csv") do |row|
  route = routes.fetch(row["route"])
  area = row["field_area"].present? ? route.field_areas.find_by!(name: row["field_area"]) : nil
  chest = TreasureChest.find_or_initialize_by(route: route, name: row["name"])
  chest.update!(
    field_area: area,
    position: to_int(row["position"]) || 0,
    discovery_type: row["discovery_type"],
    required_mapping: to_int(row["required_mapping"]) || 0,
    reward_data: row["reward_data"].presence || "{}",
respawnable: to_bool(row["respawnable"]),
  hazard_type: row["hazard_type"].presence || "normal",
  hazard_level: to_int(row["hazard_level"]) || 0
)
end

seed_rows("weapon_evolution_rules.csv") do |row|
  rule = WeaponEvolutionRule.find_or_initialize_by(source_weapon_name: row["source_weapon_name"], target_weapon_name: row["target_weapon_name"])
  rule.update!(
    required_enhancement_level: to_int(row["required_enhancement_level"]) || 10,
    required_player_level: to_int(row["required_player_level"]) || 1,
    required_floor: to_int(row["required_floor"]),
    blacksmith_location_name: row["blacksmith_location_name"].presence,
    required_materials_data: row["required_materials_data"].presence || "{}"
  )
end

seed_rows("weapon_upgrade_recipes.csv") do |row|
  recipe = WeaponUpgradeRecipe.find_or_initialize_by(
    weapon_name: row["weapon_name"].presence,
    weapon_type: row["weapon_type"].presence,
    target_level: to_int(row["target_level"])
  )
  recipe.update!(
    required_col: to_int(row["required_col"]) || 0,
    required_materials_data: row["required_materials_data"].presence || "{}"
  )
end

field_areas_index = FieldArea.all.index_by(&:name)
npcs_map = {}

seed_rows("npcs.csv") do |row|
  location   = row["location"].present?   ? locations[row["location"]]            : nil
  field_area = row["field_area"].present? ? field_areas_index[row["field_area"]]  : nil
  npc = Npc.find_or_initialize_by(code: row["code"])
  npc.update!(
    name:                      row["name"],
    npc_type:                  row["npc_type"],
    placement_type:            row["placement_type"],
    location:                  location,
    field_area:                field_area,
    facility_key:              row["facility_key"].presence,
    dungeon_key:               row["dungeon_key"].presence,
    position_key:              row["position_key"].presence,
    sort_order:                to_int(row["sort_order"]) || 0,
    active:                    to_bool(row["active"]),
    description:               row["description"].presence,
    metadata_json:             row["metadata_json"].presence || "{}",
    discovery_rate:            to_int(row["discovery_rate"]) || 50,
    repeat_discovery_required: to_bool(row["repeat_discovery_required"]),
    discovery_conditions_json: row["discovery_conditions_json"].presence || "{}",
    initial_affinity_cap:      to_int(row["initial_affinity_cap"]) || 60
  )
  npcs_map[npc.code] = npc
end

seed_rows("npc_dialogues.csv") do |row|
  npc = npcs_map.fetch(row["npc_code"])
  dialogue = NpcDialogue.find_or_initialize_by(
    npc: npc,
    dialogue_type: row["dialogue_type"],
    sequence: to_int(row["sequence"]) || 0
  )
  dialogue.update!(text: row["text"], active: to_bool(row["active"]))
end

seed_rows("npc_quests.csv") do |row|
  npc = npcs_map.fetch(row["npc_code"])
  quest = NpcQuest.find_or_initialize_by(code: row["code"])
  quest.update!(
    npc:                        npc,
    name:                       row["name"],
    description:                row["description"].presence,
    start_conditions_json:      row["start_conditions_json"].presence || "{}",
    completion_conditions_json: row["completion_conditions_json"].presence || "{}",
    reward_data:                row["reward_data"].presence || "{}",
    repeatable:                 to_bool(row["repeatable"]),
    sort_order:                 to_int(row["sort_order"]) || 0,
    active:                     to_bool(row["active"]),
    trigger_affinity:           to_int(row["trigger_affinity"])
  )
end

if File.exist?(SEED_DIR.join("npc_affinity_rules.csv"))
  NpcAffinityRuleCsvImporter.new.import!
end


if File.exist?(SEED_DIR.join("npc_affinity_cap_rules.csv"))
  NpcAffinityCapRuleCsvImporter.new.import!
end
