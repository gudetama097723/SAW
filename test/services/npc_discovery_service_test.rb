require "test_helper"

class NpcDiscoveryServiceTest < ActiveSupport::TestCase
  test "discovers a normal npc once and keeps it talkable" do
    player = players(:one)
    location = Location.create!(name: "NPC発見テスト町", floor: 1, danger_level: 0, safe_area: true)
    player.update!(location: location, level: 1)
    npc = Npc.create!(code: "normal_test_npc", name: "普通のNPC", placement_type: "town", location: location, discovery_rate: 100)

    result = NpcDiscoveryService.discover_during_stroll!(player)
    discovery = player.npc_discoveries.find_by!(npc: npc)

    assert result.discovered?
    assert discovery.talkable?
    assert_equal 1, discovery.discovered_count

    second = NpcDiscoveryService.discover_during_stroll!(player)
    assert_not second.discovered?
    assert_equal 1, discovery.reload.discovered_count
  end

  test "rare npc can require rediscovery after speaking" do
    player = players(:one)
    location = Location.create!(name: "レアNPCテスト町", floor: 1, danger_level: 0, safe_area: true)
    player.update!(location: location)
    npc = Npc.create!(
      code: "rare_test_npc",
      name: "滅多にいないNPC",
      placement_type: "town",
      location: location,
      discovery_rate: 100,
      repeat_discovery_required: true
    )

    NpcDiscoveryService.discover_during_stroll!(player)
    discovery = player.npc_discoveries.find_by!(npc: npc)
    discovery.mark_spoken!

    assert_not discovery.reload.talkable?

    result = NpcDiscoveryService.discover_during_stroll!(player)

    assert result.discovered?
    assert discovery.reload.talkable?
    assert_equal 2, discovery.discovered_count
  end

  test "discovery conditions can require level skills and items" do
    player = players(:one)
    location = Location.create!(name: "条件NPCテスト町", floor: 1, danger_level: 0, safe_area: true)
    player.update!(location: location, level: 2)
    npc = Npc.create!(
      code: "condition_test_npc",
      name: "条件付きNPC",
      placement_type: "town",
      location: location,
      discovery_rate: 100,
      discovery_conditions_json: {
        level: { min: 3 },
        skills: ["探索"],
        items: [{ name: "紹介状", quantity: 1 }]
      }.to_json
    )

    assert_not NpcDiscoveryService.discover_during_stroll!(player).discovered?

    player.update!(level: 3)
    player.skills.create!(name: "探索", proficiency: 1)
    player.items.create!(name: "紹介状", category: "misc", quantity: 1)

    result = NpcDiscoveryService.discover_during_stroll!(player)

    assert result.discovered?
    assert player.npc_discoveries.find_by!(npc: npc).talkable?
  end

  test "discovery rate can prevent finding an npc" do
    player = players(:one)
    location = Location.create!(name: "発見率テスト町", floor: 1, danger_level: 0, safe_area: true)
    player.update!(location: location)
    Npc.create!(code: "hidden_test_npc", name: "隠れたNPC", placement_type: "town", location: location, discovery_rate: 0)

    result = NpcDiscoveryService.discover_during_stroll!(player)

    assert_not result.discovered?
  end
end
