require "test_helper"

class EnemyAttackDamageTest < ActiveSupport::TestCase
  test "enemy attacks use 85 to 100 percent of attack power before mitigation" do
    player = players(:one)
    player.armors.update_all(equipped: false)
    mob = Mob.create!(name: "攻撃幅テストmob", hp: 100, atk: 100, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 1, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |range| range.begin }
    minimum_damage = BattleService.enemy_attack_damage(player, enemy, nil)
    BattleService.singleton_class.define_method(:rand) { |range| range.end }
    maximum_damage = BattleService.enemy_attack_damage(player, enemy, nil)
  ensure
    BattleService.singleton_class.remove_method(:rand)

    assert_equal 85, minimum_damage
    assert_equal 100, maximum_damage
  end
end
