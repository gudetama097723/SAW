require "test_helper"

class WeaponShopTest < ActionDispatch::IntegrationTest
  setup do
    @location = Location.create!(name: "はじまりの街", floor: 1, danger_level: 0, safe_area: true)
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

    post blacksmith_path, params: { armor_id: armor.id, confirm_repair: "1" }
    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "repair")
    assert_equal 100, armor.reload.durability
  end
end
