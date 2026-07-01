require "test_helper"

class GameControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = Location.create!(name: "NPC操作テスト町", floor: 1, danger_level: 0, safe_area: true)
    @user = User.create!(username: "npc_controller_#{SecureRandom.hex(4)}", password: "password")
    @player = Player.create!(
      user: @user,
      name: "NPC操作テストプレイヤー",
      hp: 100,
      max_hp: 100,
      col: 100,
      floor: 1,
      location: @location,
      current_month: 3
    )

    post login_path, params: { username: @user.username, password: "password" }
  end

  test "should get index" do
    get game_path
    assert_response :success
    assert_includes response.body, "季節：春"
    assert_includes response.body, "天気：晴れ"
    assert_includes response.body, "環境：通常"
  end

  test "inn panel only shows facility npcs" do
    @player.town_discovery_for.update!(found_inn: true)
    town_guide = Npc.create!(
      code: "controller_town_guide",
      name: "街の案内人",
      placement_type: "town",
      location: @location,
      discovery_rate: 100
    )
    innkeeper = Npc.create!(
      code: "controller_innkeeper",
      name: "宿屋の主人",
      placement_type: "facility",
      facility_key: "inn",
      location: @location,
      discovery_rate: 100
    )
    @player.npc_discoveries.create!(npc: town_guide, currently_available: true, acquainted: true, affinity: 1)
    @player.npc_discoveries.create!(npc: innkeeper, currently_available: true, acquainted: true, affinity: 1)

    get game_path, params: { panel: "inn" }

    assert_response :success
    assert_includes response.body, "宿屋の主人に話しかける"
    assert_not_includes response.body, "街の案内人に話しかける"
  end

  test "inn can sleep until specified time" do
    @player.town_discovery_for.update!(found_inn: true)
    @player.update!(hp: 50, max_hp: 100, current_time: 22 * 60 + 30)

    post inn_path, params: { wake_hour: 6, wake_minute: 0 }

    assert_redirected_to game_path(panel: "inn")
    assert_equal 6 * 60, @player.reload.current_time
    assert_includes flash[:notice], "450分経過した"
  end

  test "cannot accept quest from undiscovered npc by direct post" do
    npc = Npc.create!(
      code: "controller_hidden_npc",
      name: "未発見NPC",
      placement_type: "town",
      location: @location,
      discovery_rate: 100
    )
    quest = NpcQuest.create!(code: "controller_hidden_quest", name: "未発見クエスト", npc: npc)

    assert_no_difference -> { @player.player_quests.count } do
      post npc_accept_quest_path, params: { npc_quest_id: quest.id }
    end

    assert_redirected_to game_path
    assert_equal "未発見NPCには今は話しかけられません。", flash[:alert]
  end

  test "cannot use currently unavailable npc by direct post" do
    npc = Npc.create!(
      code: "controller_unavailable_npc",
      name: "再発見待ちNPC",
      placement_type: "town",
      location: @location,
      discovery_rate: 100
    )
    @player.npc_discoveries.create!(npc: npc, currently_available: false, acquainted: true, affinity: 1)

    post npc_gossip_path, params: { npc_id: npc.id }

    assert_redirected_to game_path
    assert_equal "再発見待ちNPCには今は話しかけられません。", flash[:alert]
    assert_equal 1, @player.npc_discoveries.find_by!(npc: npc).affinity
  end

  test "cannot talk to discovered npc placed in another location" do
    other_location = Location.create!(name: "NPC操作テスト別町", floor: 1, danger_level: 0, safe_area: true)
    npc = Npc.create!(
      code: "controller_other_place_npc",
      name: "別場所NPC",
      placement_type: "town",
      location: other_location,
      discovery_rate: 100
    )
    @player.npc_discoveries.create!(npc: npc, currently_available: true, acquainted: true, affinity: 1)

    post npc_info_path, params: { npc_id: npc.id }

    assert_redirected_to game_path
    assert_equal "別場所NPCには今は話しかけられません。", flash[:alert]
    assert_equal 1, @player.npc_discoveries.find_by!(npc: npc).affinity
  end

  test "rare npc becomes unavailable after conversation action" do
    npc = Npc.create!(
      code: "controller_rare_npc",
      name: "通りすがりNPC",
      placement_type: "town",
      location: @location,
      discovery_rate: 100,
      repeat_discovery_required: true
    )
    npc.npc_dialogues.create!(dialogue_type: "gossip", text: "また会えたな。")
    npc.npc_affinity_rules.create!(action_type: "chat", affinity_gain: 1, daily_limit: true)
    discovery = @player.npc_discoveries.create!(npc: npc, currently_available: true, acquainted: true, affinity: 1)

    post npc_gossip_path, params: { npc_id: npc.id }

    assert_redirected_to game_path(panel: "npc_menu", npc_id: npc.id)
    assert_not discovery.reload.talkable?
    assert_equal 2, discovery.affinity
    assert discovery.last_spoken_at.present?
  end
end
