require "test_helper"

class NpcQuestServiceTest < ActiveSupport::TestCase
  test "one time quest cannot be accepted after completion" do
    player = players(:one)
    quest = create_quest(code: "service_one_time", repeatable: false)

    assert NpcQuestService.accept_quest!(player, quest).status == :ok
    assert NpcQuestService.complete_quest!(player, quest).status == :ok

    result = NpcQuestService.accept_quest!(player, quest)

    assert_equal :error, result.status
    assert_equal "このクエストは達成済みです。", result.message
    assert_not_includes NpcQuestService.available_quests(player, quest.npc), quest
  end

  test "repeatable quest cannot be accepted again on the same game day" do
    player = players(:one)
    player.update!(current_month: 1, current_day: 1)
    quest = create_quest(code: "service_repeatable", repeatable: true, quest_type: "delivery")

    assert NpcQuestService.accept_quest!(player, quest).status == :ok
    assert NpcQuestService.complete_quest!(player, quest).status == :ok

    result = NpcQuestService.accept_quest!(player, quest)

    assert_equal :error, result.status
    assert_equal "この依頼は本日達成済みです。明日また受注できます。", result.message
    assert_not_includes NpcQuestService.available_quests(player, quest.npc), quest
  end

  test "repeatable quest can be accepted again on the next game day" do
    player = players(:one)
    player.update!(current_month: 1, current_day: 1)
    quest = create_quest(code: "service_repeatable_next_day", repeatable: true, quest_type: "delivery")

    assert NpcQuestService.accept_quest!(player, quest).status == :ok
    assert NpcQuestService.complete_quest!(player, quest).status == :ok

    player.update!(current_day: 2)
    result = NpcQuestService.accept_quest!(player, quest)

    assert_equal :ok, result.status
    player_quest = player.player_quests.find_by!(npc_quest: quest)
    assert player_quest.active?
    assert_equal 1, player_quest.completed_count
    assert_includes NpcQuestService.active_quests(player, quest.npc), player_quest
  end

  private

  def create_quest(code:, repeatable:, quest_type: "npc")
    npc = Npc.create!(
      code: "#{code}_npc",
      name: "クエスト試験NPC",
      npc_type: "guide",
      placement_type: "town",
      location: locations(:one),
      discovery_rate: 100
    )
    NpcQuest.create!(
      code: code,
      name: "試験クエスト",
      npc: npc,
      repeatable: repeatable,
      quest_type: quest_type,
      completion_conditions_json: "{}",
      reward_data: "{}"
    )
  end
end
