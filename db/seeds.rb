town = Location.find_or_create_by!(name: "はじまりの街") do |location|
  location.floor = 1
  location.danger_level = 0
  location.safe_area = true
end

grassland = Location.find_or_create_by!(name: "はじまりの草原") do |location|
  location.floor = 1
  location.danger_level = 30
  location.safe_area = false
end

next_town = Location.find_or_create_by!(name: "ホルンカの村") do |location|
  location.floor = 1
  location.danger_level = 0
  location.safe_area = true
end

forest = Location.find_or_create_by!(name: "静寂の森") do |location|
  location.floor = 1
  location.danger_level = 50
  location.safe_area = false
end

Route.find_or_create_by!(from_location: town, to_location: grassland) do |route|
  route.travel_time = 15
  route.danger_level = 10
end

Route.find_or_create_by!(from_location: grassland, to_location: town) do |route|
  route.travel_time = 15
  route.danger_level = 10
end

Route.find_or_create_by!(from_location: grassland, to_location: next_town) do |route|
  route.travel_time = 30
  route.danger_level = 20
end

Route.find_or_create_by!(from_location: next_town, to_location: grassland) do |route|
  route.travel_time = 30
  route.danger_level = 20
end

Route.find_or_create_by!(from_location: grassland, to_location: forest) do |route|
  route.travel_time = 25
  route.danger_level = 30
end

Route.find_or_create_by!(from_location: forest, to_location: grassland) do |route|
  route.travel_time = 25
  route.danger_level = 30
end

player = Player.find_or_create_by!(name: "キリト") do |p|
  p.hp = 100
  p.col = 0
  p.floor = 1
  p.location = town
  p.current_time = 480
end

player.update!(
  location: town,
  current_time: 480,
  level: player.level.presence || 1,
  exp: player.exp.presence || 0,
  max_hp: player.max_hp.presence || 100,
  strength: player.strength.presence || 1,
  agility: player.agility.presence || 1,
  stat_points: player.stat_points.presence || 0,
  skill_slots: player.skill_slots.presence || 3
)

Weapon.find_or_create_by!(player: player, name: "スモールソード") do |weapon|
  weapon.weapon_type = "片手直剣"
  weapon.rarity = "common"
  weapon.attack_power = 6
  weapon.durability = 30
  weapon.max_durability = 30
  weapon.hp_bonus = 0
  weapon.strength_bonus = 1
  weapon.agility_bonus = 0
  weapon.critical_rate = 5
  weapon.equipped = true
end
player.weapons.find_by(name: "スモールソード")&.update!(critical_rate: 5)

Armor.find_or_create_by!(player: player, name: "レザーチュニック") do |armor|
  armor.armor_type = "体防具"
  armor.slot = "body"
  armor.rarity = "common"
  armor.defense = 2
  armor.weight = 2
  armor.hp_bonus = 5
  armor.strength_bonus = 0
  armor.agility_bonus = 0
  armor.equipped = true
end

Armor.find_or_create_by!(player: player, name: "レザーブーツ") do |armor|
  armor.armor_type = "ブーツ"
  armor.slot = "feet"
  armor.rarity = "common"
  armor.defense = 0
  armor.weight = 1
  armor.hp_bonus = 0
  armor.strength_bonus = 0
  armor.agility_bonus = 1
  armor.equipped = true
end

skill = Skill.find_or_create_by!(
  player: player,
  name: "片手剣"
) do |s|
  s.proficiency = 0
end

skill.proficiency += 1
skill.save!

slime = Mob.find_or_create_by!(name: "スライム") do |mob|
  mob.hp = 10
  mob.atk = 3
  mob.rarity = "normal"
end
slime.update!(level: 1, hp: 10, atk: 3, agility: 1, rarity: "normal", durability: 1, exp_reward: 8)
MobPart.find_or_create_by!(mob: slime, name: "核") do |part|
  part.damage_multiplier = 100
  part.weakness = true
end
MobPart.find_or_create_by!(mob: slime, name: "外膜") do |part|
  part.damage_multiplier = 70
  part.weakness = false
end

rabbit = Mob.find_or_create_by!(name: "ホーンラビット") do |mob|
  mob.hp = 15
  mob.atk = 5
  mob.rarity = "normal"
end
rabbit.update!(level: 2, hp: 15, atk: 5, agility: 4, rarity: "normal", durability: 2, exp_reward: 12)
MobPart.find_or_create_by!(mob: rabbit, name: "角") do |part|
  part.damage_multiplier = 100
  part.weakness = true
end
MobPart.find_or_create_by!(mob: rabbit, name: "胴体") do |part|
  part.damage_multiplier = 80
  part.weakness = false
end
MobPart.find_or_create_by!(mob: rabbit, name: "脚") do |part|
  part.damage_multiplier = 70
  part.weakness = false
end

mutant_slime = Mob.find_or_create_by!(name: "変異スライム") do |mob|
  mob.hp = 30
  mob.atk = 10
  mob.rarity = "rare"
end
mutant_slime.update!(level: 4, hp: 30, atk: 10, agility: 2, rarity: "rare", durability: 4, exp_reward: 25)
MobPart.find_or_create_by!(mob: mutant_slime, name: "赤い核") do |part|
  part.damage_multiplier = 100
  part.weakness = true
end
MobPart.find_or_create_by!(mob: mutant_slime, name: "硬質外膜") do |part|
  part.damage_multiplier = 65
  part.weakness = false
end

kobold = Mob.find_or_create_by!(name: "コボルド歩哨") do |mob|
  mob.hp = 24
  mob.atk = 8
  mob.rarity = "normal"
end
kobold.update!(level: 3, hp: 24, atk: 8, agility: 3, rarity: "normal", durability: 3, exp_reward: 18)
MobPart.find_or_create_by!(mob: kobold, name: "首") do |part|
  part.damage_multiplier = 100
  part.weakness = true
end
MobPart.find_or_create_by!(mob: kobold, name: "手") do |part|
  part.damage_multiplier = 80
  part.weakness = false
end
MobPart.find_or_create_by!(mob: kobold, name: "足") do |part|
  part.damage_multiplier = 75
  part.weakness = false
end
Weapon.find_or_create_by!(mob: kobold, name: "錆びたショートソード") do |weapon|
  weapon.weapon_type = "片手直剣"
  weapon.rarity = "common"
  weapon.attack_power = 4
  weapon.durability = 12
  weapon.max_durability = 18
  weapon.hp_bonus = 0
  weapon.strength_bonus = 0
  weapon.agility_bonus = 0
  weapon.critical_rate = 3
  weapon.drop_rate = 20
end
kobold.weapons.find_by(name: "錆びたショートソード")&.update!(critical_rate: 3)

[
  [slime, "核", 8, nil, "スライムの核", 35],
  [slime, "外膜", 12, nil, nil, 0],
  [rabbit, "角", 6, nil, "ホーンラビットの角", 50],
  [rabbit, "胴体", 12, nil, nil, 0],
  [rabbit, "脚", 8, "agility_down", nil, 0],
  [mutant_slime, "赤い核", 12, nil, "変異スライムの核", 40],
  [mutant_slime, "硬質外膜", 18, nil, nil, 0],
  [kobold, "首", 10, nil, nil, 0],
  [kobold, "手", 9, "strength_down", nil, 0],
  [kobold, "足", 9, "agility_down", nil, 0]
].each do |mob, part_name, durability, break_effect, drop_item_name, drop_rate|
  part = MobPart.find_by!(mob: mob, name: part_name)
  part.update!(
    max_durability: durability,
    break_effect: break_effect,
    drop_item_name: drop_item_name,
    drop_rate: drop_rate
  )
end
