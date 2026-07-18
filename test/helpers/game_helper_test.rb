require "test_helper"

class GameHelperTest < ActionView::TestCase
  test "formats enhanced weapon attack for equipment display" do
    weapon = Weapon.new(attack_power: 14, sharpness_level: 1)

    assert_equal "14.6", formatted_attack_power(weapon.base_effective_attack_power)
    assert_equal "14.56", formatted_attack_power(weapon.base_effective_attack_power, precision: 2)
    assert_equal "4", formatted_attack_bonus_percent(weapon)
  end
end
