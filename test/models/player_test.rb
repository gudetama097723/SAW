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
    player.status_values = { poison: 3, sleep: 0, custom_status: true }.to_json

    assert_equal ["重症", "毒", "custom_status"], player.condition_labels
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
end
