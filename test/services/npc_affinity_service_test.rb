require "test_helper"

class NpcAffinityServiceTest < ActiveSupport::TestCase
  test "chat affinity gain is limited once per game day" do
    player = players(:one)
    npc = Npc.create!(code: "affinity_chat_npc", name: "雑談NPC", placement_type: "town", location: locations(:one), discovery_rate: 100)
    npc.npc_affinity_rules.create!(action_type: "chat", affinity_gain: 1, daily_limit: true)
    relation = player.npc_discoveries.create!(npc: npc, currently_available: true, affinity: 1)

    first = NpcAffinityService.gain!(player, npc, action_type: "chat")
    second = NpcAffinityService.gain!(player, npc, action_type: "chat")

    assert first.ok?
    assert_not second.ok?
    assert_equal 2, relation.reload.affinity
  end

  test "gift consumes item and applies matching rule" do
    player = players(:one)
    npc = Npc.create!(code: "affinity_gift_npc", name: "贈り物NPC", placement_type: "town", location: locations(:one), discovery_rate: 100)
    npc.npc_affinity_rules.create!(action_type: "gift", target_key: "薬草", affinity_gain: 2, daily_limit: true)
    player.npc_discoveries.create!(npc: npc, currently_available: true, affinity: 1)
    item = player.items.create!(name: "薬草", category: "gathered", quantity: 1)

    result = NpcAffinityService.gift!(player, npc, "薬草")

    assert result.ok?
    assert_equal 3, player.npc_discoveries.find_by!(npc: npc).affinity
    assert_not Item.exists?(item.id)
  end

  test "affinity gains stop at the current affinity cap" do
    player = players(:one)
    npc = Npc.create!(code: "affinity_cap_npc", name: "上限NPC", placement_type: "town", location: locations(:one), discovery_rate: 100, initial_affinity_cap: 60)
    npc.npc_affinity_rules.create!(action_type: "quest_clear", target_key: "ordinary", affinity_gain: 10)
    relation = player.npc_discoveries.create!(npc: npc, currently_available: true, affinity: 58, affinity_cap: 60)

    result = NpcAffinityService.gain!(player, npc, action_type: "quest_clear", target_key: "ordinary")

    assert_equal 60, result.affinity
    assert_equal 2, result.gain
    assert_equal "友人", relation.reload.affinity_stage
  end

  test "cap rules unlock staged affinity caps when conditions are met" do
    player = players(:one)
    npc = Npc.create!(code: "affinity_unlock_npc", name: "上限解放NPC", placement_type: "town", location: locations(:one), discovery_rate: 100, initial_affinity_cap: 60)
    npc.npc_affinity_cap_rules.create!(cap_value: 80, unlock_type: "quest_clear", unlock_key: "trust_trial", required_affinity: 60)
    relation = player.npc_discoveries.create!(npc: npc, currently_available: true, affinity: 60, affinity_cap: 60)

    result = NpcAffinityCapService.unlock!(player, npc, unlock_type: "quest_clear", unlock_key: "trust_trial")

    assert result.ok?
    assert_equal 80, relation.reload.affinity_cap
  end

  test "cap one hundred allows special affinity stage" do
    player = players(:one)
    npc = Npc.create!(code: "affinity_special_npc", name: "特別NPC", placement_type: "town", location: locations(:one), discovery_rate: 100, initial_affinity_cap: 99)
    npc.npc_affinity_rules.create!(action_type: "event_clear", target_key: "master_oath", affinity_gain: 20)
    npc.npc_affinity_cap_rules.create!(cap_value: 100, unlock_type: "event_clear", unlock_key: "master_oath", required_affinity: 99)
    relation = player.npc_discoveries.create!(npc: npc, currently_available: true, affinity: 99, affinity_cap: 99)

    cap_result = NpcAffinityCapService.unlock!(player, npc, unlock_type: "event_clear", unlock_key: "master_oath")
    affinity_result = NpcAffinityService.gain!(player, npc, action_type: "event_clear", target_key: "master_oath")

    assert cap_result.ok?
    assert_equal 100, affinity_result.affinity
    assert_equal "特別", relation.reload.affinity_stage
  end
end
