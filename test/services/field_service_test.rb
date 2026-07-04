require "test_helper"

class FieldServiceTest < ActiveSupport::TestCase
  test "starting grassland gathering can yield poison mushrooms" do
    items = FieldService.gatherable_items_for(Route.new(name: "はじまりの草原"))

    assert_includes items, "毒キノコ"
    assert_operator items.count("毒キノコ"), :<, items.count("薬草")
  end

  test "gathering catalog loads item category from csv" do
    definition = GatheringCatalog.definitions_for(Route.new(name: "はじまりの草原")).find do |candidate|
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

  test "night raises roaming enemy levels" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "夜間テスト道", danger_level: 20)
    mob = mobs(:one)
    mob.update!(level: 2)
    player.update!(field_route: route, current_time: 23 * 60)

    assert_equal 6, FieldService.enemy_level_for(player, mob)
  end

  test "starting grassland enemy levels follow mob identity" do
    player = players(:one)
    route = routes(:one)
    route.update!(name: "はじまりの草原")
    player.update!(field_route: route, current_time: 12 * 60)

    slime = mobs(:one)
    slime.update!(name: "スライム", level: 1)
    scout = mobs(:two)
    scout.update!(name: "コボルド斥候", rarity: "rare", level: 3)

    FieldService.singleton_class.define_method(:rand) { |*| 0 }
    begin
      assert_equal 1, FieldService.enemy_level_for(player, slime)
      assert_equal 3, FieldService.enemy_level_for(player, scout)
    ensure
      FieldService.singleton_class.remove_method(:rand)
    end
  end

  test "field bosses are not level based" do
    mob = mobs(:one)
    mob.update!(boss_type: "field_boss", level: 14)
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_max_hp: 100, enemy_level: 14, position: 1)

    assert_not enemy.level_based?
    assert_equal mob.name, enemy.display_name
    assert_equal 100, enemy.effective_max_hp
  end
end
