require "test_helper"

class RestaurantServiceTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @location.update!(name: "はじまりの街", safe_area: true)
    @player = players(:one)
    @player.items.destroy_all
    @player.update!(location: @location, col: 1_000, current_time: 480, satiety: 50, buff_effects: "{}")
  end

  test "eat normal restaurant menu restores satiety and applies time buff" do
    result = RestaurantService.eat_menu!(@player, "黒パンとシチュー")

    assert_equal :ok, result.status
    @player.reload
    assert_equal 965, @player.col
    assert_equal 500, @player.current_time
    assert_in_delta 69.44, @player.satiety.to_f, 0.01
    assert_equal 10, BuffEffectService.time_effects(@player).dig("restaurant:はじまりの街:黒パンとシチュー", "hp")
    assert_equal 120, BuffEffectService.time_effects(@player).dig("restaurant:はじまりの街:黒パンとシチュー", "remaining_minutes")
  end

  test "eat special restaurant menu consumes required ingredient" do
    @player.items.create!(name: "薬草", category: "gathered", quantity: 5)

    result = RestaurantService.eat_menu!(@player, "薬草リゾット")

    assert_equal :ok, result.status
    @player.reload
    assert_equal 920, @player.col
    assert_equal 505, @player.current_time
    assert_nil @player.items.find_by(name: "薬草")
    assert_equal 1, BuffEffectService.time_effects(@player).dig("restaurant:はじまりの街:薬草リゾット", "strength")
    assert_equal 5, BuffEffectService.time_effects(@player).dig("restaurant:はじまりの街:薬草リゾット", "accuracy")
  end
end
