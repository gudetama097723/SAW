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

  test "battle commands hide weapon actions without combat weapon" do
    @player.weapons.destroy_all
    mob = Mob.create!(name: "武器なし表示テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    @player.battles.create!(mob: mob, enemy_hp: 10)

    get game_path
    assert_response :success
    assert_includes response.body, "戦闘"
    assert_not_includes response.body, "battle_command=sword_skill"

    get game_path, params: { battle_command: "battle" }
    assert_response :success
    assert_includes response.body, "素手攻撃"
    assert_not_includes response.body, "パリィを狙う"

    get game_path, params: { battle_command: "attack" }
    assert_response :success
    assert_includes response.body, "素手攻撃"
    assert_not_includes response.body, "武器攻撃"

    get game_path, params: { battle_command: "sword_skill" }
    assert_response :success
    assert_includes response.body, "素手攻撃"
    assert_not_includes response.body, "片手直剣スキル"
  end

  test "battle actions reject direct weapon commands without combat weapon" do
    @player.weapons.destroy_all
    mob = Mob.create!(name: "武器なし直叩きテストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = @player.battles.create!(mob: mob, enemy_hp: 10)
    BattleService.ensure_battle_enemies!(battle)
    part = BattleService.ensure_mob_parts!(mob).first

    post attack_path, params: { attack_group: "weapon_attack", mob_part_id: part.id }
    assert_redirected_to game_path(battle_command: "attack")
    assert_equal "武器を装備していないため、武器攻撃はできません。", flash[:alert]

    post sword_skill_path, params: { skill: "vertical", mob_part_id: part.id }
    assert_redirected_to game_path(battle_command: "attack")
    assert_equal "武器を装備していないため、ソードスキルは使用できません。", flash[:alert]
  end

  test "battle command links keep selected single enemy target" do
    mob = Mob.create!(name: "対象保持テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = @player.battles.create!(mob: mob, enemy_hp: 10)
    BattleService.ensure_battle_enemies!(battle)
    left_enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 2)

    get game_path, params: { target_enemy_id: left_enemy.id }

    assert_response :success
    assert_match(/target_enemy_id=#{left_enemy.id}.*battle_command=battle|battle_command=battle.*target_enemy_id=#{left_enemy.id}/, response.body)
  end

  test "area skill selection shows limit warning" do
    mob = Mob.create!(name: "範囲選択上限テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = @player.battles.create!(mob: mob, enemy_hp: 10)
    @player.weapons.create!(name: "範囲選択テスト剣", weapon_type: "片手直剣", rarity: "common", attack_power: 1, durability: 10, max_durability: 10, equipped: true)
    @player.skills.create!(name: "片手直剣", proficiency: 50, skill_exp: 0, skill_category: "weapon", weapon_skill: true)
    BattleService.ensure_battle_enemies!(battle)
    enemies = battle.battle_enemies.to_a
    4.times do |index|
      enemies << battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: index + 2)
    end

    get game_path, params: {
      battle_command: "sword_skill",
      skill_group: "sword_skill",
      selected_skill: "horizontal",
      target_enemy_ids: enemies.first(4).map(&:id).join(","),
      selection_error: "too_many"
    }

    assert_response :success
    assert_includes response.body, "これ以上選択できません。"
    assert_includes response.body, "選択中: 4 / 4"
  end

  test "paralysis blocks battle item escape and equipment actions" do
    mob = Mob.create!(name: "麻痺操作不能テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = @player.battles.create!(mob: mob, enemy_hp: 10)
    potion = @player.items.create!(name: "ポーション", category: "healing", quantity: 1)
    weapon = @player.weapons.create!(name: "麻痺中装備テスト剣", weapon_type: "片手直剣", rarity: "common", attack_power: 1, durability: 10, max_durability: 10)
    @player.update!(status_effects: { paralysis: { active: true, turns: 3 } }.to_json)

    post use_battle_item_path, params: { item_name: "ポーション" }
    assert_redirected_to game_path(battle_command: "item")
    assert_equal 1, potion.reload.quantity
    assert_includes flash[:notice], "麻痺して動けない"

    post escape_path
    assert_redirected_to game_path
    assert Battle.exists?(battle.id)
    assert_includes flash[:notice], "麻痺して動けない"

    post equip_weapon_path, params: { weapon_id: weapon.id }
    assert_redirected_to game_path(battle_command: "attack")
    assert_not weapon.reload.equipped?
    assert_includes flash[:notice], "麻痺が解けた"
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

  test "can allocate some or all stat points" do
    @player.update!(stat_points: 3, strength: 10, agility: 10)

    post allocate_stats_path, params: { strength_points: 1, agility_points: 0 }

    assert_redirected_to game_path(panel: "growth")
    @player.reload
    assert_equal 2, @player.stat_points
    assert_equal 11, @player.strength
    assert_equal 10, @player.agility

    @player.update!(stat_points: 6, strength: 10, agility: 10)

    post allocate_stats_path, params: { strength_points: 4, agility_points: 2 }

    assert_redirected_to game_path(panel: "growth")
    @player.reload
    assert_equal 0, @player.stat_points
    assert_equal 14, @player.strength
    assert_equal 12, @player.agility
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

  test "npc info shows one dialogue line at a time" do
    npc = Npc.create!(
      code: "controller_info_npc",
      name: "情報NPC",
      placement_type: "town",
      location: @location,
      discovery_rate: 100
    )
    npc.npc_dialogues.create!(dialogue_type: "info", sequence: 1, text: "一つ目の情報")
    npc.npc_dialogues.create!(dialogue_type: "info", sequence: 2, text: "二つ目の情報")
    @player.npc_discoveries.create!(npc: npc, currently_available: true, acquainted: true, affinity: 1)

    post npc_info_path, params: { npc_id: npc.id }

    assert_redirected_to game_path(panel: "npc_menu", npc_id: npc.id)
    assert_equal 1, flash[:notice].scan("情報NPC「").size
    assert_not_includes flash[:notice], "」 / 情報NPC「"
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
