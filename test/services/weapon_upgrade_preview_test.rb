require "test_helper"

class WeaponUpgradePreviewTest < ActiveSupport::TestCase
  setup do
    @weapon = Weapon.new(
      name: "強化表示テスト剣",
      weapon_type: "片手直剣",
      attack_power: 14,
      part_break_power: 100,
      critical_rate: 5,
      durability: 100,
      max_durability: 100
    )
  end

  test "sharpness and heaviness previews show attack and part break changes" do
    sharpness = WeaponUpgradeService.effect_previews_for(@weapon, "S")
    heaviness = WeaponUpgradeService.effect_previews_for(@weapon, "H")

    assert_preview sharpness.first, before: 14.0, after: 14.56
    assert_preview sharpness.second, before: 100.0, after: 100.5
    assert_preview heaviness.first, before: 14.0, after: 14.14
    assert_preview heaviness.second, before: 100.0, after: 104.0
  end

  test "quickness accuracy and durability previews show their concrete changes" do
    quickness = WeaponUpgradeService.effect_previews_for(@weapon, "Q")
    accuracy = WeaponUpgradeService.effect_previews_for(@weapon, "A")
    durability = WeaponUpgradeService.effect_previews_for(@weapon, "D")

    assert_equal 5, quickness.size
    assert_preview quickness.first, before: 0.0, after: 2.0
    assert_preview quickness.last, before: 0.0, after: 3.6
    assert_preview accuracy.first, before: 0, after: 3
    assert_preview accuracy.second, before: 5, after: 6
    assert_preview durability.first, before: 100, after: 110
    assert_preview durability.second, before: 100.0, after: 97.0
  end

  private

  def assert_preview(preview, before:, after:)
    assert_in_delta before, preview.before_value, 0.0001
    assert_in_delta after, preview.after_value, 0.0001
  end
end
