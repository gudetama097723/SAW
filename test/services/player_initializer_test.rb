require "test_helper"

class PlayerInitializerTest < ActiveSupport::TestCase
  test "new player starts with body legs and shoes equipped" do
    user = User.create!(username: "initializer_#{SecureRandom.hex(4)}", password: "password")
    player = PlayerInitializer.create_for_user!(user)

    assert_equal %w[body feet legs], player.equipped_armors.pluck(:slot).sort
    assert_equal 3, player.equipped_armors.count
    assert player.equipped_armors.all? { |armor| armor.durability == armor.max_durability }
  end
end
