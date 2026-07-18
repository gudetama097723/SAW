require "test_helper"

class WeaponUpgradeConfirmationTest < ActionDispatch::IntegrationTest
  setup do
    location = Location.create!(name: "強化確認の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    user = User.create!(username: "upgrade_confirmation_#{SecureRandom.hex(4)}", password: "password")
    @player = Player.create!(user: user, name: "強化確認テスト", hp: 100, max_hp: 100, col: 100_000, floor: 1, location: location, current_time: 600)
    @player.town_discovery_for.update!(found_blacksmith: true)
    blacksmith = Npc.create!(
      code: "upgrade_confirmation_blacksmith",
      name: "強化確認鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: location,
      blacksmith_base_proficiency: 100,
      blacksmith_max_proficiency: 100
    )
    @player.npc_discoveries.create!(npc: blacksmith, currently_available: true)
    @weapon = @player.weapons.create!(
      name: "アイアンショートソード",
      weapon_type: "片手直剣",
      attack_power: 14,
      durability: 100,
      max_durability: 100,
      enhance_limit: 10,
      enhancement_difficulty: 1.0
    )
    @player.items.create!(name: "硬い甲殻", category: "drop", quantity: 10)
    post login_path, params: { username: user.username, password: "password" }
  end

  test "upgrade screen starts compact and expands only the selected enhancement" do
    get game_path(panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: @weapon.id, smith_mode: "npc")

    assert_response :success
    %w[鋭さ 速さ 正確さ 重さ 丈夫さ].each do |name|
      assert_includes response.body, "#{name}を強化"
    end
    assert_not_includes response.body, "成功時の変化"
    assert_not_includes response.body, "必要熟練度"
    assert_not_includes response.body, "S："

    get game_path(
      panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: @weapon.id,
      smith_mode: "npc", confirm_upgrade_type: "S"
    )

    assert_includes response.body, "成功時の変化"
    assert_includes response.body, "14.00"
    assert_includes response.body, "14.56"
    assert_includes response.body, "必要熟練度"
  end

  test "upgrade requires explicit yes confirmation before consuming an attempt" do
    get game_path(
      panel: "blacksmith",
      blacksmith_menu: "upgrade",
      weapon_id: @weapon.id,
      smith_mode: "npc",
      confirm_upgrade_type: "S"
    )

    assert_response :success
    assert_includes response.body, "鋭さを強化しますか？"
    assert_includes response.body, "はい"
    assert_includes response.body, "いいえ"

    assert_no_changes -> { @weapon.reload.enhance_attempts } do
      post upgrade_weapon_path, params: { weapon_id: @weapon.id, enhancement_type: "S", smith_mode: "npc" }
    end
    assert_redirected_to game_path(
      panel: "blacksmith",
      blacksmith_menu: "upgrade",
      weapon_id: @weapon.id,
      smith_mode: "npc",
      confirm_upgrade_type: "S"
    )

    assert_difference -> { @weapon.reload.enhance_attempts }, 1 do
      post upgrade_weapon_path, params: { weapon_id: @weapon.id, enhancement_type: "S", smith_mode: "npc", confirm_upgrade: "1" }
    end
  end

  test "blacksmith selection appears only after learning blacksmithing" do
    get game_path(panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: @weapon.id)
    assert_not_includes response.body, "鍛冶を行う者を選択"

    @player.skills.create!(name: "鍛冶", proficiency: 0, skill_exp: 0, skill_category: "production")
    get game_path(panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: @weapon.id)

    assert_includes response.body, "鍛冶を行う者を選択"
    assert_includes response.body, "強化確認鍛冶師"
    assert_match(/>自分<\/a>/, response.body)
    assert_not_includes response.body, "NPCへ依頼"
  end
end
