require "test_helper"

class WeaponTest < ActiveSupport::TestCase
  test "durability condition reduces effective attack power" do
    weapon = Weapon.new(name: "テスト剣", weapon_type: "片手直剣", attack_power: 100, max_durability: 200)

    weapon.durability = 200
    assert_equal "良好", weapon.durability_condition_label
    assert_equal 100, weapon.effective_attack_power

    weapon.durability = 100
    assert_equal "消耗", weapon.durability_condition_label
    assert_equal 85, weapon.effective_attack_power

    weapon.durability = 50
    assert_equal "損傷", weapon.durability_condition_label
    assert_equal 70, weapon.effective_attack_power

    weapon.durability = 20
    assert_equal "破損寸前", weapon.durability_condition_label
    assert_equal 50, weapon.effective_attack_power

    weapon.durability = 0
    assert_equal "破損", weapon.durability_condition_label
    assert_equal 10, weapon.effective_attack_power
  end

  test "large damage and loss thresholds use negative durability" do
    weapon = Weapon.new(name: "テスト剣", weapon_type: "片手直剣", attack_power: 10, durability: -40, max_durability: 200)

    assert weapon.major_damage?
    assert_not weapon.lost_by_durability?

    weapon.durability = -51
    assert weapon.lost_by_durability?
  end

  test "broken weapons require repair materials" do
    wolf_sword = Weapon.new(name: "蒼狼の牙剣", weapon_type: "片手直剣", durability: 0, max_durability: 360)
    rapier = Weapon.new(name: "テストレイピア", weapon_type: "細剣", durability: 0, max_durability: 180)
    damaged = Weapon.new(name: "傷ついた剣", weapon_type: "片手直剣", durability: 10, max_durability: 200)

    assert_equal({ "狼王の牙" => 1 }, wolf_sword.repair_materials_required)
    assert_equal({ "薄羽蜂の針" => 1 }, rapier.repair_materials_required)
    assert_empty damaged.repair_materials_required
  end
end
