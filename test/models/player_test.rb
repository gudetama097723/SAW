require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "satiety starts at max" do
    assert_equal 100, Player.new.satiety.to_i
    assert_equal 100, Player.new.max_satiety
  end

  test "advance time reduces satiety to zero over six in-game hours" do
    player = players(:one)
    player.satiety = player.max_satiety

    player.advance_time!(180)
    assert_in_delta 50, player.satiety.to_f, 0.01

    player.advance_time!(180)
    assert_equal 0, player.satiety.to_i
  end

  test "satiety drain scales with future max value" do
    player = players(:one)

    player.define_singleton_method(:max_satiety) { 120 }
    player.satiety = player.max_satiety

    player.advance_time!(360)

    assert_equal 0, player.satiety.to_i
  end
end
