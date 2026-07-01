require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "satiety starts at max" do
    assert_equal 100, Player.new.satiety.to_i
    assert_equal 100, Player.new.max_satiety
  end

  test "current season follows current month" do
    player = Player.new(current_month: 3)
    assert_equal "spring", player.current_season
    assert_equal "春", player.current_season_label

    player.current_month = 8
    assert_equal "summer", player.current_season
    assert_equal "夏", player.current_season_label

    player.current_month = 11
    assert_equal "autumn", player.current_season
    assert_equal "秋", player.current_season_label

    player.current_month = 12
    assert_equal "winter", player.current_season
    assert_equal "冬", player.current_season_label
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

  test "sleep value rises after fifteen awake hours" do
    player = players(:one)
    player.update!(awake_minutes_since_sleep: 15 * 60)

    player.advance_time!(60)

    assert_equal 10, player.status_value_data["sleep"]
  end

  test "sleep value reaches cap and activates sleep" do
    player = players(:one)
    player.update!(awake_minutes_since_sleep: 15 * 60, status_values: { sleep: 90 }.to_json)

    player.advance_time!(60)

    assert StatusEffectService.active?(player, "sleep")
    assert_equal "限界だ……", player.sleepiness_warning_message
  end

  test "rest recovery reduces recoverable status values by ten percent and clears low values" do
    player = players(:one)
    player.status_values = { poison: 50, burn: 4, curse: 50 }.to_json
    StatusEffectService.activate!(player, "poison")
    StatusEffectService.activate!(player, "burn")
    StatusEffectService.activate!(player, "curse")

    StatusEffectService.rest_recover_values!(player)

    assert_equal 45, player.status_value_data["poison"]
    assert_nil player.status_value_data["burn"]
    assert_equal 50, player.status_value_data["curse"]
    assert_not StatusEffectService.active?(player, "burn")
    assert StatusEffectService.active?(player, "curse")
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
    routes(:one).update!(danger_level: 100)
    player.update!(field_route: routes(:one), field_position: 0)
    StatusEffectService.activate!(player, "sleep")

    result = FieldService.field_status_interruption!(player)

    assert_equal :encounter, result.status
    assert result.battle
    assert StatusEffectService.active?(player, "sleep")
    assert_not player.rests.exists?
  end

  test "time buff directly modifies player stats and expires by time" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    before_hp = player.effective_max_hp

    BuffEffectService.apply_time_buff!(player, "test_food", { hp: 20, strength: 3, agility: 2, accuracy: 10 }, duration_minutes: 5)

    assert_equal before_hp + 20, player.effective_max_hp
    assert_equal 13, player.effective_strength
    assert_equal 12, player.effective_agility
    assert_equal 10, BuffEffectService.accuracy_modifier(player)

    player.advance_time!(5)

    assert_empty BuffEffectService.time_effects(player)
  end

  test "battle effect modifies battle enemy stats and expires by turns" do
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mobs(:one), enemy_hp: 100, enemy_max_hp: 100, enemy_level: 1, position: 1)
    enemy.mob.update!(atk: 10, agility: 10)

    BuffEffectService.apply_battle_effect!(enemy, "rage", { attack_percent: 50, agility_percent: -20 }, turns: 1)

    assert_equal 15, enemy.effective_atk
    assert_equal 8, enemy.effective_agility

    BuffEffectService.tick_battle_turn!(enemy)

    assert_empty BuffEffectService.battle_effects(enemy)
  end
end
