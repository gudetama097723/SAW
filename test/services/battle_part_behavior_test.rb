require "test_helper"

class BattlePartBehaviorTest < ActiveSupport::TestCase
  test "weak part near destruction raises critical chance without guaranteeing it" do
    player, enemy, part = build_battle_part(weakness: true, max_durability: 10)
    enemy.part_states = { part.id.to_s => { "durability" => 1, "broken" => false } }.to_json
    enemy.save!
    weapon = Weapon.new(weapon_type: "片手直剣", critical_rate: 0)

    BattleService.singleton_class.define_method(:rand) { |_range| 24 }
    begin
      assert_not BattleService.critical_hit?(player, weapon, enemy, part, 1)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    BattleService.singleton_class.define_method(:rand) { |_range| 9 }
    begin
      assert BattleService.critical_hit?(player, weapon, enemy, part, 1)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "broken part has increased critical chance and is guarded by an intact non-weak part" do
    player, enemy, broken_part = build_battle_part(weakness: true, max_durability: 10)
    weak_part = enemy.mob.mob_parts.create!(name: "弱点", damage_multiplier: 100, weakness: true, max_durability: 10)
    guard_part = enemy.mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false, max_durability: 10)
    enemy.part_states = {
      broken_part.id.to_s => { "durability" => 0, "broken" => true },
      weak_part.id.to_s => { "durability" => 10, "broken" => false },
      guard_part.id.to_s => { "durability" => 10, "broken" => false }
    }.to_json
    enemy.save!
    weapon = Weapon.new(weapon_type: "片手直剣", critical_rate: 0)

    BattleService.singleton_class.define_method(:rand) { |_range| 14 }
    begin
      assert BattleService.critical_hit?(player, weapon, enemy, broken_part, 1)
      guarded = BattleService.resolve_guarded_part(player, enemy, [broken_part, weak_part, guard_part], broken_part)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert guarded[:guarded]
    assert_equal guard_part, guarded[:part]
  end

  test "broken part is not guarded when no intact non-weak part remains" do
    player, enemy, broken_part = build_battle_part(weakness: true, max_durability: 10)
    other_part = enemy.mob.mob_parts.create!(name: "別の弱点", damage_multiplier: 100, weakness: true, max_durability: 10)
    enemy.part_states = {
      broken_part.id.to_s => { "durability" => 0, "broken" => true },
      other_part.id.to_s => { "durability" => 0, "broken" => true }
    }.to_json
    enemy.save!

    BattleService.singleton_class.define_method(:rand) { |_range| 0 }
    begin
      guarded = BattleService.resolve_guarded_part(player, enemy, [broken_part, other_part], broken_part)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_not guarded[:guarded]
    assert_equal broken_part, guarded[:part]
  end

  private

  def build_battle_part(weakness:, max_durability:)
    player = players(:one)
    mob = Mob.create!(name: "部位挙動テストmob", hp: 100, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 1, flee_rate: 0)
    part = mob.mob_parts.create!(name: "頭", damage_multiplier: 100, weakness: weakness, max_durability: max_durability)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)
    [player, enemy, part]
  end
end
