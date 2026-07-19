require "test_helper"

class WeaponShopTest < ActionDispatch::IntegrationTest
  setup do
    @location = Location.create!(name: "ヴィーゲンブルク", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    @user = User.create!(username: "weapon_shop_#{SecureRandom.hex(4)}", password: "password")
    @player = Player.create!(user: @user, name: "武具店テスト", hp: 100, max_hp: 100, col: 1_000, floor: 1, location: @location, current_time: 600)
    @player.town_discovery_for.update!(found_weapon_shop: true)
    post login_path, params: { username: @user.username, password: "password" }
  end

  test "weapon shop sells weapons and armor" do
    get game_path
    assert_response :success
    assert_includes response.body, "武具店に入る"
    assert_match(/data-details-state-key="world-facilities" open/, response.body)

    get game_path, params: { panel: "weapon_shop" }
    assert_response :success
    assert_includes response.body, "武器を購入"
    assert_includes response.body, "防具を購入"
    assert_includes response.body, "武具を売却"
    assert_includes response.body, "施設から出る"
    assert_includes response.body, "左のメニューから行動を選択してください。"

    get game_path, params: { panel: "weapon_shop", shop_menu: "weapons" }
    assert_response :success
    assert_includes response.body, "ブロンズソード"
    assert_not_includes response.body, "攻撃 9"

    get game_path, params: { panel: "weapon_shop", shop_menu: "armors", slot: "hands" }
    assert_response :success
    assert_includes response.body, "レザーグローブ"
    assert_not_includes response.body, "レザーチュニック"

    get game_path, params: { panel: "weapon_shop", shop_menu: "armors", equipment_name: "レザーグローブ", confirm_purchase: "1" }
    assert_includes response.body, "購入しますか？"
    assert_includes response.body, "はい"
    assert_includes response.body, "いいえ"

    post weapon_shop_path, params: { equipment_type: "armor", equipment_name: "レザーグローブ", confirm_purchase: "1" }
    assert_redirected_to game_path(panel: "weapon_shop", shop_menu: "armors")
    armor = @player.armors.find_by!(name: "レザーグローブ")
    assert_equal "hands", armor.slot
    assert_equal armor.max_durability, armor.durability

    post weapon_shop_path, params: { equipment_type: "weapon", equipment_name: "ブロンズソード", confirm_purchase: "1" }
    assert_redirected_to game_path(panel: "weapon_shop", shop_menu: "weapons")
    weapon = @player.weapons.find_by!(name: "ブロンズソード")
    assert_equal "片手直剣", weapon.weapon_type
    assert_equal weapon.max_durability, weapon.durability
  end


  test "weapon shop sells weapons and armor after confirmation" do
    weapon = @player.weapons.create!(name: "売却テスト剣", weapon_type: "片手直剣", attack_power: 5, durability: 100, max_durability: 100)
    armor = @player.armors.create!(name: "売却テスト鎧", armor_type: "革鎧", slot: "body", defense: 3, durability: 100, max_durability: 100)

    get game_path, params: { panel: "weapon_shop", shop_menu: "sell", sell_type: "armors", armor_id: armor.id, confirm_sell: "1" }
    assert_response :success
    assert_includes response.body, "売却しますか？"

    post sell_armor_path, params: { armor_id: armor.id, confirm_sell: "1" }
    assert_nil @player.armors.find_by(id: armor.id)

    get game_path, params: { panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons", weapon_id: weapon.id, confirm_sell: "1" }
    assert_includes response.body, "売却しますか？"
    post sell_weapon_path, params: { weapon_id: weapon.id, confirm_sell: "1" }
    assert_nil @player.weapons.find_by(id: weapon.id)
  end

  test "shops show currently owned counts when buying or producing" do
    @player.town_discovery_for.update!(found_item_shop: true, found_blacksmith: true)
    @player.items.create!(name: "ポーション", category: "healing", quantity: 3)
    2.times do
      @player.weapons.create!(name: "ブロンズソード", weapon_type: "片手直剣", attack_power: 9, durability: 240, max_durability: 240)
    end
    @player.weapons.create!(name: "蒼狼の牙剣", weapon_type: "片手直剣", attack_power: 18, durability: 360, max_durability: 360)
    @player.armors.create!(name: "レザーグローブ", armor_type: "革鎧", slot: "hands", defense: 1, durability: 100, max_durability: 100)

    get game_path, params: { panel: "item_shop", shop_menu: "buy", item_name: "ポーション" }
    assert_response :success
    assert_includes response.body, "現所持数: 3個"

    get game_path, params: { panel: "item_shop", shop_menu: "produce" }
    assert_response :success
    assert_includes response.body, "現所持数: 3個"

    get game_path, params: { panel: "weapon_shop", shop_menu: "weapons", equipment_name: "ブロンズソード" }
    assert_response :success
    assert_includes response.body, "現所持数: 2本"

    get game_path, params: { panel: "weapon_shop", shop_menu: "armors", equipment_name: "レザーグローブ" }
    assert_response :success
    assert_includes response.body, "現所持数: 1個"

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "produce", weapon_name: "蒼狼の牙剣" }
    assert_response :success
    assert_includes response.body, "現所持数: 1本"
  end

  test "blacksmith repairs armor but does not sell weapons" do
    @player.town_discovery_for.update!(found_blacksmith: true)
    armor = @player.armors.create!(name: "整備テスト鎧", armor_type: "革鎧", slot: "body", defense: 4, durability: 20, max_durability: 100)

    get game_path, params: { panel: "blacksmith" }
    assert_response :success
    assert_not_includes response.body, "武器を購入する"

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc" }
    assert_response :success
    assert_includes response.body, "防具整備"
    assert_includes response.body, armor.name
    assert_includes response.body, "耐久 20 / 100"

    post blacksmith_path, params: { armor_id: armor.id, confirm_repair: "1" }
    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "repair")
    assert_equal 100, armor.reload.durability
  end

  test "blacksmith repairs all damaged weapons and armor together" do
    @player.town_discovery_for.update!(found_blacksmith: true)
    Npc.create!(
      code: "bulk_repair_blacksmith",
      name: "一括整備鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: @location,
      blacksmith_base_proficiency: 100,
      blacksmith_max_proficiency: 200
    )
    weapon = @player.weapons.create!(name: "一括整備剣", weapon_type: "片手直剣", durability: 40, max_durability: 100, maintenance_level: 0)
    armor = @player.armors.create!(name: "一括整備鎧", armor_type: "革鎧", slot: "body", durability: 20, max_durability: 100)
    col_before = @player.col

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc" }
    assert_response :success
    assert_includes response.body, "すべて整備する"

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc", confirm_repair_all: "1" }
    assert_response :success
    assert_includes response.body, "すべて整備しますか？"
    assert_includes response.body, "対象: 2点"

    post blacksmith_path, params: { repair_all: "1", confirm_repair: "1", smith_mode: "npc" }

    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc")
    assert_equal weapon.effective_max_durability, weapon.reload.durability
    assert_equal armor.max_durability, armor.reload.durability
    assert_operator @player.reload.col, :<, col_before
    assert_includes flash[:notice], "まとめて整備した"
  end

  test "bulk blacksmith repair handles weapons and armor when no npc blacksmith is available" do
    @player.town_discovery_for.update!(found_blacksmith: true)
    weapon = @player.weapons.create!(name: "NPC不在整備剣", weapon_type: "片手直剣", durability: 40, max_durability: 100, maintenance_level: 0)
    armor = @player.armors.create!(name: "NPC不在整備鎧", armor_type: "革鎧", slot: "body", durability: 20, max_durability: 100)

    post blacksmith_path, params: { repair_all: "1", confirm_repair: "1", smith_mode: "npc" }

    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc")
    assert_equal weapon.effective_max_durability, weapon.reload.durability
    assert_equal armor.max_durability, armor.reload.durability
    assert_includes flash[:notice], "まとめて整備した"
  end

  test "blacksmith information can enter conversation with its facility npc" do
    @player.town_discovery_for.update!(found_blacksmith: true)
    npc = Npc.create!(
      code: "weapon_shop_blacksmith_npc",
      name: "会話試験鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: @location,
      discovery_rate: 100,
      blacksmith_base_proficiency: 80,
      blacksmith_max_proficiency: 120
    )

    get game_path, params: { panel: "blacksmith" }

    assert_response :success
    assert_includes response.body, "会話試験鍛冶師に話しかける"

    post talk_to_npc_path, params: { npc_id: npc.id }
    assert_redirected_to game_path(panel: "npc_menu", npc_id: npc.id)
  end

  test "self blacksmithing is shown and accepted only with the blacksmith skill" do
    @player.town_discovery_for.update!(found_blacksmith: true)

    get game_path, params: { panel: "blacksmith" }
    assert_not_includes response.body, "自分で鍛冶を行う"
    assert_not_includes response.body, "鍛冶を行う者を選択"
    assert_not_includes response.body, "NPCへ依頼"
    assert_nil BlacksmithService.context_for(@player, mode: "player")
    assert_no_difference -> { @player.weapons.count } do
      post produce_weapon_path, params: {
        smith_mode: "player",
        confirm_produce: "1",
        weapon_type: "片手直剣",
        ore_material: "鉄鉱",
        monster_material: "ホーンラビットの角",
        support_material: "精錬石"
      }
    end
    assert_includes flash[:alert], "鍛冶を行える実行者がいません"

    @player.skills.create!(name: "鍛冶", proficiency: 0, skill_exp: 0, skill_category: "production")
    get game_path, params: { panel: "blacksmith" }

    assert_includes response.body, "自分で鍛冶を行う"
    assert_includes response.body, "鍛冶を行う者を選択"
    assert BlacksmithService.context_for(@player, mode: "player").player?
  end

  test "weapon production shows a preview before requiring confirmation to craft" do
    @player.town_discovery_for.update!(found_blacksmith: true)
    @player.skills.create!(name: "鍛冶", proficiency: 100, skill_exp: 0, skill_category: "production")
    @player.items.create!(name: "鉄鉱", category: "material", quantity: 10)
    @player.items.create!(name: "ホーンラビットの角", category: "material", quantity: 3)
    @player.items.create!(name: "精錬石", category: "material", quantity: 2)

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "produce", smith_mode: "player" }
    assert_response :success
    assert_not_includes response.body, "鍛造プレビュー"

    preview_params = {
      panel: "blacksmith", blacksmith_menu: "produce", smith_mode: "player",
      weapon_type: "片手直剣", ore_material: "鉄鉱", monster_material: "ホーンラビットの角", support_material: "精錬石"
    }
    get game_path, params: preview_params
    assert_response :success
    assert_includes response.body, "鍛造プレビュー"
    assert_includes response.body, "この内容で鍛造する"

    assert_no_difference -> { @player.weapons.count } do
      post produce_weapon_path, params: preview_params.except(:panel, :blacksmith_menu)
    end

    assert_difference -> { @player.weapons.count }, 1 do
      post produce_weapon_path, params: preview_params.except(:panel, :blacksmith_menu).merge(confirm_produce: "1")
    end
  end

  test "direct blacksmith access is rejected where no facility exists" do
    @player.location.update!(has_blacksmith_facility: false)

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "produce" }

    assert_redirected_to game_path
    assert_includes flash[:alert], "鍛造できる設備がない"
  end

  test "self maintenance is available from equipment while traveling" do
    @player.skills.create!(name: "鍛冶", proficiency: 0, skill_exp: 0, skill_category: "production")
    @player.items.create!(
      name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1,
      durability: 30, max_durability: 30
    )
    weapon = @player.weapons.create!(
      name: "街道整備試験剣", weapon_type: "片手直剣", attack_power: 10,
      durability: 40, max_durability: 100, maintenance_level: 0
    )
    destination = Location.create!(name: "街道整備の行先", floor: 1, safe_area: true)
    route = Route.create!(from_location: @location, to_location: destination, name: "街道整備ルート")
    @player.update!(field_route: route)

    get game_path, params: { panel: "equipment" }
    assert_response :success
    assert_includes response.body, "整備キットで自己整備"

    post blacksmith_path, params: { weapon_id: weapon.id, smith_mode: "player" }
    assert_redirected_to game_path(panel: "equipment")
    assert_equal 100, weapon.reload.durability
  end
end
