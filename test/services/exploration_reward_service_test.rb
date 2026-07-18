require "test_helper"

class ExplorationRewardServiceTest < ActiveSupport::TestCase
  test "box treasure can be opened without inspection" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "テスト宝箱",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: { col: 10 }.to_json
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    result = ExplorationRewardService.open_treasure!(player, treasure)

    assert_equal :ok, result.status
    assert_equal 10, player.reload.col
    assert_includes result.message, "[treasure_reward]10刻銭を入手した。[/treasure_reward]"
  end

  test "inspected box treasure can be opened" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "テスト宝箱",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: { col: 10 }.to_json
    )
    state = player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    inspect_result = ExplorationRewardService.inspect_treasure!(player, treasure)
    open_result = ExplorationRewardService.open_treasure!(player, treasure)

    assert_equal :ok, inspect_result.status
    assert_equal :ok, open_result.status
    assert_equal 10, player.reload.col
    assert state.reload.opened?
  end

  test "lost item style treasure can still be collected without inspection" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "旅人の忘れ物",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: { col: 5 }.to_json
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    result = ExplorationRewardService.open_treasure!(player, treasure)

    assert_equal :ok, result.status
    assert_equal 5, player.reload.col
  end

  test "normal inspection does not use exploration skill" do
    player = create_player!
    player.skills.create!(name: "探索", proficiency: 0, skill_exp: 0)
    route = create_route!
    area = create_area!(route)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "罠付きの箱",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: "{}",
      hazard_type: "trap",
      hazard_level: 1
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    result = ExplorationRewardService.inspect_treasure!(player, treasure)

    assert_equal :ok, result.status
    assert_not_includes result.message, "探索スキルを使って確認した"
    assert_equal 0, player.skills.find_by(name: "探索").skill_exp
  end

  test "exploration skill can be used as a treasure action" do
    player = create_player!
    player.skills.create!(name: "探索", proficiency: 0, skill_exp: 0)
    route = create_route!
    area = create_area!(route)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "罠付きの箱",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: "{}",
      hazard_type: "trap",
      hazard_level: 1
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    result = ExplorationRewardService.use_treasure_skill!(player, treasure, "探索")

    assert_equal :ok, result.status
    assert_includes result.message, "探索スキルを使って確認した"
    assert_operator player.skills.find_by(name: "探索").skill_exp, :>, 0
  end

  test "ignored treasure remains available while player stays in the same area" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    player.update!(field_route: route, field_position: 0)
    treasure = TreasureChest.create!(
      route: route,
      field_area: area,
      name: "テスト宝箱",
      position: 0,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: "{}"
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    result = ExplorationRewardService.ignore_treasure!(player, treasure)

    assert_equal :ok, result.status
    assert_includes ExplorationRewardService.discovered_treasure_states(player), player.player_treasure_chests.find_by(treasure_chest: treasure)
    assert_empty ExplorationRewardService.pending_treasure_states(player)
  end

  test "discovered treasure is only available in current area" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    other_area = create_area!(route)
    other_area.update!(name: "別区画", start_distance: 101, end_distance: 200)
    player.update!(field_route: route, field_position: 0)
    treasure = TreasureChest.create!(
      route: route,
      field_area: other_area,
      name: "別区画の宝箱",
      position: 101,
      discovery_type: "fixed",
      required_mapping: 0,
      reward_data: "{}"
    )
    player.player_treasure_chests.create!(treasure_chest: treasure, found: true)

    assert_empty ExplorationRewardService.discovered_treasure_states(player)
  end

  test "fenrir is discovered after full mapping and five pack leader defeats" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    player.update!(field_route: route, field_position: 0)
    player.progress_for_area(area).update!(mapping_progress: 100)
    pack_leader = create_boss!(name: "群狼の王", route: route, field_area: area, boss_type: "area_boss")
    fenrir = create_boss!(name: "蒼狼フェンリル", route: route, boss_type: "field_boss")
    player.player_boss_kills.create!(mob: pack_leader, found: true, defeated: true, defeated_count: 4)

    assert_nil ExplorationRewardService.discover_field_boss!(player)
    assert_nil player.player_boss_kills.find_by(mob: fenrir)

    player.player_boss_kills.find_by(mob: pack_leader).update!(defeated_count: 5)
    message = ExplorationRewardService.discover_field_boss!(player)

    assert_includes message, "フィールドボス「蒼狼フェンリル」を発見した"
    assert player.player_boss_kills.find_by(mob: fenrir).found?
  end

  test "boss victories count repeated defeats after the first clear" do
    player = create_player!
    route = create_route!
    area = create_area!(route)
    boss = create_boss!(name: "群狼の王", route: route, field_area: area, boss_type: "area_boss", reward_data: { col: 10 }.to_json)

    first_message = ExplorationRewardService.boss_victory_message!(player, boss)
    second_message = ExplorationRewardService.boss_victory_message!(player, boss)
    state = player.player_boss_kills.find_by!(mob: boss)

    assert_equal 2, state.defeated_count
    assert_includes first_message, "10刻銭を入手した"
    assert_not_includes second_message, "10刻銭を入手した"
  end

  private

  def create_player!
    location = Location.create!(name: "テストの街", floor: 1, safe_area: true, danger_level: 1)
    Player.create!(name: "Tester", location: location, floor: 1, hp: 100, max_hp: 100, col: 0)
  end

  def create_route!
    from = Location.create!(name: "出発地", floor: 1, safe_area: true, danger_level: 1)
    to = Location.create!(name: "目的地", floor: 1, safe_area: true, danger_level: 1)
    Route.create!(name: "テスト草原", from_location: from, to_location: to, distance: 100, travel_time: 10, danger_level: 1)
  end

  def create_area!(route)
    FieldArea.create!(
      route: route,
      name: "テスト区画",
      start_distance: 0,
      end_distance: 100,
      encounter_rate: 0,
      rest_safety: 100
    )
  end

  def create_boss!(name:, route:, boss_type:, field_area: nil, reward_data: "{}")
    Mob.create!(
      name: name,
      route: route,
      field_area: field_area,
      boss_type: boss_type,
      hp: 100,
      atk: 10,
      rarity: "boss",
      level: 1,
      agility: 1,
      durability: 1,
      exp_reward: 10,
      flee_rate: 0,
      reward_data: reward_data
    )
  end
end
