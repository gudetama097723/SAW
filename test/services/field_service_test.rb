require "test_helper"

class FieldServiceTest < ActiveSupport::TestCase
  test "starting grassland gathering can yield poison mushrooms" do
    items = FieldService.gatherable_items_for(Route.new(name: "ゆりかごの野"))

    assert_includes items, "毒キノコ"
    assert_operator items.count("毒キノコ"), :<, items.count("薬草")
  end

  test "gathering catalog loads item category from csv" do
    definition = GatheringCatalog.definitions_for(Route.new(name: "ゆりかごの野")).find do |candidate|
      candidate.item_name == "毒キノコ"
    end

    assert_equal "gathered", definition.category
    assert_equal 1, definition.weight
  end

  test "field rest requires a tent unless rest encounter chance is zero" do
    player = players(:one)
    area = field_areas(:one)
    area.update!(rest_safety: 70)
    player.items.destroy_all
    player.update!(field_route: routes(:one), field_position: area.start_distance)

    assert_not FieldService.field_rest_available?(player)

    player.items.create!(name: "持ち運びテント", category: "misc", quantity: 1)

    assert FieldService.field_rest_available?(player)
    assert_equal 21, FieldService.rest_encounter_chance(player)

    player.items.destroy_all
    area.update!(rest_safety: 100)

    assert FieldService.field_rest_available?(player)
    assert_equal 0, FieldService.rest_encounter_chance(player)
  end

  test "rest encounter destroys the best available tent" do
    player = players(:one)
    area = field_areas(:one)
    area.update!(rest_safety: 0)
    player.items.destroy_all
    player.rests.destroy_all
    player.update!(field_route: routes(:one), field_position: area.start_distance)
    player.rests.create!
    player.items.create!(name: "持ち運びテント", category: "misc", quantity: 1)
    player.items.create!(name: "高級持ち運びテント", category: "misc", quantity: 1)

    FieldService.singleton_class.define_method(:rand) { |*| 0 }
    begin
      result = FieldService.rest_encounter!(player)

      assert_equal :encounter, result.status
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end

    assert_nil player.items.find_by(name: "高級持ち運びテント")
    assert_equal 1, player.items.find_by(name: "持ち運びテント").quantity
    assert_not player.rests.exists?
  end

  test "night raises field danger and encounter chance" do
    player = players(:one)
    route = routes(:one)
    route.update!(danger_level: 20)
    player.update!(field_route: route, current_time: 22 * 60)

    assert_equal 50, FieldService.effective_field_danger_level(player)
    assert_equal 72, FieldService.field_encounter_chance(40, player)
  end

  test "hunt encounter is not guaranteed to be an ambush" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "ゆりかごの野")
    player.update!(field_route: route, current_time: 12 * 60)
    rolls = 0

    FieldService.singleton_class.define_method(:rand) do |arg = nil|
      rolls += 1
      if rolls == 1
        0
      elsif rolls == 2
        99
      else
        arg.is_a?(Range) ? arg.begin : 0
      end
    end
    begin
      result = FieldService.hunt!(player)
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert result.battle
    assert_not result.battle.ambush?
    assert_not_includes result.message, "先制攻撃のチャンス"
  end

  test "stealth skill lowers field detection and raises hunt ambush chance" do
    player = players(:one)
    route = routes(:one)
    player.skills.destroy_all
    player.update!(field_route: route, current_time: 12 * 60)

    detection_without_stealth = FieldService.stealth_adjusted_encounter_chance(40, player)
    ambush_without_stealth = FieldService.hunt_ambush_chance(player)

    player.skills.create!(name: "隠蔽", proficiency: 1000, skill_exp: 0)

    assert_operator FieldService.stealth_adjusted_encounter_chance(40, player), :<, detection_without_stealth
    assert_operator FieldService.hunt_ambush_chance(player), :>, ambush_without_stealth
  end

  test "mapping gain is lower in dangerous areas" do
    player = players(:one)
    route = routes(:one)
    area = field_areas(:one)
    route.update!(danger_level: 20)
    player.skills.destroy_all
    player.update!(field_route: route, field_position: area.start_distance, current_time: 12 * 60)

    FieldService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 99 }
    begin
      area.update!(encounter_rate: 20)
      safe_gain = FieldService.mapping_gain_for(0, player, route)

      area.update!(encounter_rate: 60)
      danger_gain = FieldService.mapping_gain_for(0, player, route)

      assert_operator danger_gain, :<, safe_gain
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end
  end

  test "night reduces mapping gain even in safer areas" do
    player = players(:one)
    route = routes(:one)
    area = field_areas(:one)
    route.update!(danger_level: 20)
    area.update!(encounter_rate: 20)
    player.skills.destroy_all
    player.update!(field_route: route, field_position: area.start_distance, current_time: 22 * 60)

    FieldService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 99 }
    begin
      night_gain = FieldService.mapping_gain_for(0, player, route)
      player.update!(current_time: 12 * 60)
      day_gain = FieldService.mapping_gain_for(0, player, route)

      assert_operator night_gain, :<, day_gain
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end
  end

  test "movement cannot skip over the next field area when moving forward" do
    route = routes(:one)
    first_area = field_areas(:one)
    second_area = field_areas(:two)
    route.update!(distance: 100)
    first_area.update!(route: route, start_distance: 0, end_distance: 20)
    second_area.update!(route: route, start_distance: 21, end_distance: 50)
    FieldArea.create!(route: route, name: "third", start_distance: 51, end_distance: 100)

    assert_equal 21, FieldService.limit_position_to_adjacent_area(route, 10, 70)
  end

  test "movement cannot skip over the previous field area when moving backward" do
    route = routes(:one)
    first_area = field_areas(:one)
    second_area = field_areas(:two)
    third_area = FieldArea.create!(route: route, name: "third", start_distance: 51, end_distance: 100)
    route.update!(distance: 100)
    first_area.update!(route: route, start_distance: 0, end_distance: 20)
    second_area.update!(route: route, start_distance: 21, end_distance: 50)
    third_area.update!(route: route, start_distance: 51, end_distance: 100)

    assert_equal 50, FieldService.limit_position_to_adjacent_area(route, 80, 10)
  end

  test "night raises roaming enemy levels" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "夜間テスト道", danger_level: 20)
    mob = mobs(:one)
    mob.update!(level: 2)
    player.update!(field_route: route, current_time: 23 * 60)

    assert_equal 6, FieldService.enemy_level_for(player, mob)
  end

  test "spawn rows define enemy level ranges" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "ゆりかごの野")
    player.update!(field_route: route, current_time: 12 * 60)

    slime = mobs(:one)
    slime.update!(name: "スライム", level: 1)
    entry = { mob: slime, weight: 1, min_level: 1, max_level: 3 }

    FieldService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 0 }
    begin
      assert_equal 3, FieldService.spawn_level_for(entry, player, slime)
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end
  end

  test "encounter mobs keep player time for night spawn level bonus" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "ゆりかごの野")
    player.update!(field_route: route, current_time: 23 * 60)
    mob = mobs(:one)
    mob.update!(name: "スライム", level: 1)

    FieldService.singleton_class.define_method(:rand) do |arg = nil|
      case arg
      when Range
        arg.begin
      when Integer
        0
      else
        0
      end
    end
    begin
      encounter = FieldService.encounter_mobs_for(player).first
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end

    assert_equal "スライム", encounter.mob.name
    assert_equal 5, encounter.level
  end

  test "wolf territory can spawn pack wolves in groups of up to three" do
    player = players(:one)
    route = routes(:one)
    area = field_areas(:one)
    route.update!(name: "ゆりかごの野")
    area.update!(route: route, name: "獣道・狼の縄張り", start_distance: 91, end_distance: 120)
    player.update!(field_route: route, field_position: 95, current_time: 12 * 60)
    Mob.create!(name: "群狼", hp: 55, atk: 26, rarity: "normal", level: 6, agility: 9, durability: 8, exp_reward: 55, flee_rate: 0)

    FieldService.singleton_class.define_method(:rand) do |arg = nil|
      case arg
      when Range
        arg.end
      when Integer
        0
      else
        0
      end
    end
    begin
      encounters = FieldService.encounter_mobs_for(player)
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end

    assert_equal 3, encounters.size
    assert encounters.all? { |encounter| encounter.mob.name == "群狼" }
  end

  test "pack wolf king battle includes exactly two pack wolf companions" do
    player = players(:one)
    route = routes(:one)
    area = field_areas(:one)
    route.update!(name: "ゆりかごの野")
    area.update!(route: route, name: "獣道・狼の縄張り", start_distance: 91, end_distance: 120)
    player.update!(field_route: route, field_position: 95, current_time: 12 * 60)
    king = Mob.create!(name: "群狼の王", hp: 240, atk: 34, rarity: "boss", boss_type: "area_boss", level: 8, agility: 12, durability: 22, exp_reward: 500, flee_rate: 0)
    Mob.create!(name: "群狼", hp: 55, atk: 26, rarity: "normal", level: 6, agility: 9, durability: 8, exp_reward: 55, flee_rate: 0)

    FieldService.singleton_class.define_method(:rand) do |arg = nil|
      case arg
      when Range
        arg.end
      when Integer
        0
      else
        0
      end
    end
    begin
      battle = FieldService.create_battle!(player, [king])
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end

    enemies = battle.battle_enemies.order(:position).to_a
    names = enemies.map { |enemy| enemy.mob.name }
    assert_equal 3, names.size
    assert_equal "群狼の王", names.first
    assert_equal 2, names.count("群狼")
  end

  test "fenrir battle includes two lower level pack wolf companions" do
    player = players(:one)
    route = routes(:one)
    area = field_areas(:one)
    route.update!(name: "ゆりかごの野")
    area.update!(route: route, name: "獣道・狼の縄張り", start_distance: 91, end_distance: 120)
    player.update!(field_route: route, field_position: 95, current_time: 12 * 60)
    fenrir = Mob.create!(name: "蒼狼フェンリル", hp: 720, atk: 58, rarity: "boss", boss_type: "field_boss", level: 12, agility: 18, durability: 38, exp_reward: 1500, flee_rate: 0)
    Mob.create!(name: "群狼", hp: 55, atk: 26, rarity: "normal", level: 6, agility: 9, durability: 8, exp_reward: 55, flee_rate: 0)

    battle = FieldService.create_battle!(player, [fenrir])

    enemies = battle.battle_enemies.order(:position).to_a
    names = enemies.map { |enemy| enemy.mob.name }
    wolf_levels = enemies.select { |enemy| enemy.mob.name == "群狼" }.map(&:effective_level)

    assert_equal 3, names.size
    assert_equal "蒼狼フェンリル", names.first
    assert_equal 2, names.count("群狼")
    assert_equal [6, 6], wolf_levels
  end

  test "battle creation applies per-stat mob growth" do
    player = players(:one)
    route = routes(:one)
    player.update!(field_route: route, current_time: 12 * 60)
    mob = mobs(:one)
    mob.update!(hp: 10, atk: 4, agility: 2, durability: 1, level: 1, hp_growth: 3, atk_growth: 2, agility_growth: 1, durability_growth: 0)

    battle = FieldService.create_battle!(player, [FieldService::Encounter.new(mob: mob, level: 4)])
    enemy = battle.battle_enemies.first

    assert_equal 4, enemy.effective_level
    assert_equal 19, enemy.effective_max_hp
    assert_equal 10, enemy.effective_atk
    assert_equal 5, enemy.effective_agility
    assert_equal 1, enemy.effective_durability
  end

  test "normal battle starts enemies at middle distance" do
    player = players(:one)
    mob = mobs(:one)

    battle = FieldService.create_battle!(player, [mob])

    assert_equal ["middle"], battle.battle_enemies.map(&:distance)
  end

  test "ambush battle starts enemies at near distance" do
    player = players(:one)
    mob = mobs(:one)

    battle = FieldService.create_battle!(player, [mob], ambush: true)

    assert_equal ["near"], battle.battle_enemies.map(&:distance)
    assert_equal "enemy_ambush", battle.initiative_type
  end

  test "hunt ambush starts enemies at far distance with player initiative" do
    player = players(:one)
    mob = mobs(:one)

    battle = FieldService.create_battle!(player, [mob], initiative_type: "player_ambush")

    assert battle.ambush?
    assert_equal "player_ambush", battle.initiative_type
    assert_equal ["far"], battle.battle_enemies.map(&:distance)
  end

  test "field bosses use the same level based display and stats" do
    mob = mobs(:one)
    mob.update!(boss_type: "field_boss", hp: 100, hp_growth: 10, level: 14)
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 230, enemy_max_hp: 230, enemy_level: 14, position: 1)

    assert enemy.level_based?
    assert_equal mob.name, enemy.display_name
    assert_equal 230, enemy.effective_max_hp
  end

  test "boss levels come from csv level without time bonus" do
    player = players(:one)
    mob = mobs(:one)
    mob.update!(boss_type: "field_boss", level: 12)
    player.update!(current_time: 23 * 60)

    assert_equal 12, FieldService.enemy_level_for(player, mob)
  end
end
