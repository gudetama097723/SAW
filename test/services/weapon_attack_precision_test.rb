require "test_helper"

class WeaponAttackPrecisionTest < ActiveSupport::TestCase
  test "enhancement attack power retains fractional precision" do
    weapon = build_weapon

    assert_in_delta 14.0, weapon.base_effective_attack_power, 0.0001

    weapon.sharpness_level = 1
    assert_in_delta 14.56, weapon.base_effective_attack_power, 0.0001
    assert_in_delta 100.5, weapon.effective_part_break_power, 0.0001

    weapon.sharpness_level = 2
    assert_in_delta 15.12, weapon.base_effective_attack_power, 0.0001

    weapon.sharpness_level = 1
    weapon.heaviness_level = 1
    assert_in_delta 14.7, weapon.base_effective_attack_power, 0.0001
  end

  test "battle raw damage retains the sharpness enhancement difference" do
    player = players(:one)
    player.update!(strength: 10, agility: 10)
    mob = Mob.create!(
      name: "攻撃精度確認mob",
      hp: 100,
      atk: 1,
      rarity: "normal",
      level: 1,
      agility: 1,
      durability: 10,
      exp_reward: 1,
      flee_rate: 0
    )
    part = mob.mob_parts.create!(name: "胴体", damage_multiplier: 100)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1)
    plain_weapon = build_weapon
    enhanced_weapon = build_weapon(sharpness_level: 1)

    plain_raw_damage = BattleService.calculate_player_damage(player, plain_weapon, enemy, part, "斬撃")
    enhanced_raw_damage = BattleService.calculate_player_damage(player, enhanced_weapon, enemy, part, "斬撃")

    assert_instance_of Float, plain_raw_damage
    assert_instance_of Float, enhanced_raw_damage
    assert_operator enhanced_raw_damage, :>, plain_raw_damage
  end

  private

  def build_weapon(sharpness_level: 0)
    Weapon.new(
      name: "アイアンショートソード",
      weapon_type: "片手直剣",
      attack_power: 14,
      durability: 100,
      max_durability: 100,
      sharpness_level: sharpness_level
    )
  end
end
