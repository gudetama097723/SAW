require "test_helper"

class KeyItemTest < ActiveSupport::TestCase
  test "player can have multiple key items" do
    player = players(:one)
    player.key_items.destroy_all

    player.obtain_key_item!(name: "はじまりの街の通行証", category: "story", unique_key: "beginning_town_pass")
    player.obtain_key_item!(name: "古びた地図", category: "map", unique_key: "first_floor_old_map")

    assert_equal 2, player.key_items.count
  end

  test "key item belongs to player" do
    key_item = players(:one).obtain_key_item!(name: "老剣士の紹介状", category: "npc")

    assert_equal players(:one), key_item.player
  end

  test "same unique key is not duplicated for one player" do
    player = players(:one)
    player.key_items.destroy_all

    first = player.obtain_key_item!(name: "古びた地図", category: "map", unique_key: "first_floor_old_map")
    second = player.obtain_key_item!(name: "古びた地図", category: "map", unique_key: "first_floor_old_map")

    assert_equal first, second
    assert_equal 1, player.key_items.where(unique_key: "first_floor_old_map").count
  end

  test "different players can have same unique key" do
    players(:one).key_items.destroy_all
    players(:two).key_items.destroy_all

    players(:one).obtain_key_item!(name: "古びた地図", category: "map", unique_key: "first_floor_old_map")
    players(:two).obtain_key_item!(name: "古びた地図", category: "map", unique_key: "first_floor_old_map")

    assert_equal 2, KeyItem.where(unique_key: "first_floor_old_map").count
  end

  test "key item is not included in carry weight" do
    player = players(:one)
    player.items.destroy_all
    player.weapons.destroy_all
    player.armors.destroy_all
    player.key_items.destroy_all
    before_weight = player.carry_weight

    player.obtain_key_item!(name: "重そうな重要書類", category: "quest", unique_key: "heavy_papers")

    assert_equal before_weight, player.reload.carry_weight
  end

  test "category label is localized" do
    key_item = players(:one).obtain_key_item!(name: "古びた地図", category: "map")

    assert_equal "地図・探索情報", key_item.category_label
  end
end
