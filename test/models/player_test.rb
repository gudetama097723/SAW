require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "satiety starts at max" do
    assert_equal 100, Player.new.satiety.to_i
    assert_equal 100, Player.new.max_satiety
  end

  test "advance time reduces satiety to zero over six in-game hours" do
    player = players(:one)
    player.satiety = player.max_satiety

    player.advance_time!(180)
    assert_in_delta 50, player.satiety.to_f, 0.01

    player.advance_time!(180)
    assert_equal 0, player.satiety.to_i
  end

  test "satiety drain scales with future max value" do
    player = players(:one)

    player.define_singleton_method(:max_satiety) { 120 }
    player.satiety = player.max_satiety

    player.advance_time!(360)

    assert_equal 0, player.satiety.to_i
  end

  test "condition labels include injury severity and active statuses" do
    player = players(:one)
    player.max_hp = 100
    player.hp = 25
    StatusEffectService.activate!(player, "poison")

    assert_equal ["重症", "毒"], player.condition_labels
  end

  test "status accumulation activates status and time passage decays values" do
    player = players(:one)
    player.hp = 100
    player.max_hp = 100

    StatusEffectService.accumulate!(player, "poison", 100)
    assert StatusEffectService.active?(player, "poison")

    player.advance_time!(10)

    assert_equal 90, player.hp
    assert_operator player.status_value_data["poison"], :<, 100
  end

  test "curse reduces effective max hp" do
    player = players(:one)
    player.max_hp = 100

    StatusEffectService.activate!(player, "curse")

    assert_equal 70, player.effective_max_hp
  end

  test "death returns player to active home base inn" do
    player = players(:one)
    home_location = Location.create!(name: "本拠地の宿町", floor: 3, danger_level: 0, safe_area: true)
    player.player_bases.create!(location: home_location, base_type: "home", active: true, rent: 0, storage_limit: 30)
    player.update!(hp: 1, max_hp: 100, col: 50, floor: 9, location: locations(:one), field_route: routes(:one), field_position: 42)
    mob = Mob.create!(name: "強敵", hp: 10, atk: 100, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 1)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

    player.reload
    assert_equal :defeated, result.status
    assert_equal home_location, player.location
    assert_equal 3, player.floor
    assert_equal 0, player.col
    assert_nil player.field_route
    assert_equal 0, player.field_position
    assert_not Battle.exists?(battle.id)
  end

  test "death item penalty keeps unique items" do
    player = players(:one)
    player.items.destroy_all
    normal_item = player.items.create!(name: "普通の素材", category: "drop", quantity: 2)
    unique_item = player.items.create!(name: "唯一の牙", category: "drop", quantity: 1, unique_item: true, discardable: false)

    BattleService.apply_death_item_penalty!(player)

    assert_equal 1, normal_item.reload.quantity
    assert_equal 1, unique_item.reload.quantity
  end

  test "battle enemy can be affected by statuses" do
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mobs(:one), enemy_hp: 100, enemy_max_hp: 100, enemy_level: 1, position: 1)

    StatusEffectService.accumulate!(enemy, "burn", 100)

    assert StatusEffectService.active?(enemy, "burn")
    assert_equal ["火傷"], enemy.condition_labels
  end

  test "sleep in field forces encounter while staying asleep" do
    player = players(:one)
    player.rests.destroy_all
    player.update!(field_route: routes(:one), field_position: 0)
    StatusEffectService.activate!(player, "sleep")

    result = FieldService.field_status_interruption!(player)

    assert_equal :encounter, result.status
    assert result.battle
    assert StatusEffectService.active?(player, "sleep")
    assert_not player.rests.exists?
  end
end
