require "test_helper"

class BattleServiceTest < ActiveSupport::TestCase
  test "unarmed player can attack without equipped weapon" do
    player = players(:one)
    player.weapons.destroy_all
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    BuffEffectService.apply_battle_effect!(player, "test_sure_hit", { sure_hit: true }, turns: 1)
    mob = Mob.create!(name: "素手攻撃テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "素手攻撃",
      damage_multiplier: 100,
      durability_cost: 0,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false,
      attack_attribute: "打撃"
    )

    assert_equal :ok, result.status
    assert_includes result.message, "素手攻撃！"
  end

  test "sword skill requires equipped weapon" do
    player = players(:one)
    player.weapons.destroy_all
    mob = Mob.create!(name: "ソードスキル制限テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "バーチカル",
      damage_multiplier: 150,
      durability_cost: 2,
      skill_gain: 3,
      stiffness: true,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃"
    )

    assert_equal :error, result.status
    assert_includes result.message, "武器を装備していないため、ソードスキルは使用できません。"
  end

  test "enemy with flee rate can flee instead of attacking" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100)
    mob = Mob.create!(name: "レア逃走mob", hp: 10, atk: 100, rarity: "rare", level: 1, agility: 1, durability: 1, exp_reward: 1000, flee_rate: 100)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

    assert_equal :ok, result.status
    assert_includes result.message, "レア逃走mobは逃走した！"
    assert_includes result.message, "敵はいなくなった。"
    assert_equal 100, player.reload.hp
    assert_not Battle.exists?(battle.id)
  end

  test "zero flee rate enemy attacks normally" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100)
    mob = Mob.create!(name: "通常mob", hp: 10, atk: 10, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

    assert_equal :ok, result.status
    assert_includes result.message, "通常mobの攻撃！"
    assert Battle.exists?(battle.id)
    assert_operator player.reload.hp, :<, 100
  end
end
