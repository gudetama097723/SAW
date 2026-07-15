require "test_helper"

class ArmorTest < ActiveSupport::TestCase
  test "equipping armor replaces only armor in the same slot" do
    player = players(:one)
    first_body = player.armors.create!(name: "最初の胴防具", armor_type: "革鎧", slot: "body", equipped: true)
    feet = player.armors.create!(name: "靴防具", armor_type: "革鎧", slot: "feet", equipped: true)
    second_body = player.armors.create!(name: "次の胴防具", armor_type: "革鎧", slot: "body", equipped: true)

    assert_not first_body.reload.equipped?
    assert feet.reload.equipped?
    assert second_body.reload.equipped?
    assert_equal 1, player.equipped_armors.where(slot: "body").count
  end

  test "legs and shoes are separate equipment slots" do
    assert_includes Armor::EQUIPPABLE_SLOTS, "legs"
    assert_includes Armor::EQUIPPABLE_SLOTS, "feet"
    assert_equal "脚", Armor.slot_name("legs")
    assert_equal "靴", Armor.slot_name("feet")
  end

  test "durability lowers defense and creates a repair cost" do
    armor = Armor.new(name: "耐久テスト鎧", armor_type: "革鎧", slot: "body", defense: 10, weight: 2, durability: 20, max_durability: 100)

    assert_equal 7, armor.effective_defense
    assert armor.repair_cost.positive?
    armor.durability = 100
    assert_equal 10, armor.effective_defense
    assert_equal 0, armor.repair_cost
  end
end
