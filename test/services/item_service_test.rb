require "test_helper"

class ItemServiceTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @location.update!(name: "はじまりの街", safe_area: true)
    @player = players(:one)
    @player.items.destroy_all
    @player.update!(location: @location, col: 1_000, current_time: 480, satiety: 100)
  end

  test "buy shop item supports quantity" do
    result = ItemService.buy_shop_item!(@player, "ポーション", quantity: 3)

    assert_equal :ok, result.status
    assert_equal 850, @player.reload.col
    assert_equal 495, @player.current_time
    assert_equal 3, @player.items.find_by!(name: "ポーション").quantity
  end

  test "produce potion supports quantity" do
    @player.items.create!(name: "薬草", category: "gathered", quantity: 30)

    result = ItemService.produce_potion!(@player, quantity: 2)

    assert_equal :ok, result.status
    assert_equal 960, @player.reload.col
    assert_equal 510, @player.current_time
    assert_equal 10, @player.items.find_by!(name: "薬草").quantity
    assert_equal 2, @player.items.find_by!(name: "ポーション").quantity
  end
end
