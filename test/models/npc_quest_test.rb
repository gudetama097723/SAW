require "test_helper"

class NpcQuestTest < ActiveSupport::TestCase
  test "new quests default to one time npc quests" do
    quest = NpcQuest.new(
      code: "default_one_time",
      name: "初期値確認",
      npc: test_npc
    )

    assert quest.valid?
    assert_not quest.repeatable?
    assert_equal "npc", quest.quest_type
    assert_equal "NPC固有クエスト", quest.quest_type_label
  end

  test "quest type labels are localized" do
    quest = NpcQuest.new(
      code: "localized_delivery",
      name: "納品",
      npc: test_npc,
      quest_type: "delivery",
      repeatable: true
    )

    assert_equal "納品依頼", quest.quest_type_label
    assert_equal "簡易依頼", quest.display_kind_label
    assert_equal "再受注可能", quest.repeatability_label
  end

  test "npc and repeatable quests expose different ui labels" do
    npc_quest = NpcQuest.new(code: "ui_npc", name: "一度きり", npc: test_npc, quest_type: "npc")
    repeatable_quest = NpcQuest.new(code: "ui_board", name: "掲示板", npc: test_npc, quest_type: "board", repeatable: true)

    assert_equal "クエスト", npc_quest.display_kind_label
    assert_equal "達成済み", npc_quest.completed_label
    assert_equal "簡易依頼", repeatable_quest.display_kind_label
    assert_equal "達成済み・再受注可能", repeatable_quest.completed_label
  end

  private

  def test_npc
    @test_npc ||= Npc.create!(
      code: "npc_quest_model_test",
      name: "クエスト試験NPC",
      npc_type: "guide",
      placement_type: "town",
      location: locations(:one),
      discovery_rate: 100
    )
  end
end
