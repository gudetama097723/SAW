require "test_helper"

class WeaponTest < ActiveSupport::TestCase
  test "equipping a weapon replaces the current weapon without dual wield" do
    player = players(:one)
    first = player.weapons.create!(name: "最初の剣", weapon_type: "片手直剣", equipped: true)
    second = player.weapons.create!(name: "次の剣", weapon_type: "片手直剣", equipped: true)

    assert_not first.reload.equipped?
    assert second.reload.equipped?
    assert_equal 1, player.equipped_weapons.count
  end

  test "dual wield allows two equipped weapons but replaces the oldest third weapon" do
    player = players(:one)
    player.skills.create!(name: "二刀流", proficiency: 0)
    first = player.weapons.create!(name: "二刀流の一振り目", weapon_type: "片手直剣", equipped: true)
    second = player.weapons.create!(name: "二刀流の二振り目", weapon_type: "片手直剣", equipped: true)
    third = player.weapons.create!(name: "二刀流の三振り目", weapon_type: "片手直剣", equipped: true)

    assert_not first.reload.equipped?
    assert second.reload.equipped?
    assert third.reload.equipped?
    assert_equal 2, player.equipped_weapons.count
  end

  test "one handed weapon types are identified for shields" do
    assert Weapon.new(weapon_type: "片手直剣").one_handed?
    assert Weapon.new(weapon_type: "細剣").one_handed?
    refute Weapon.new(weapon_type: "両手剣").one_handed?
    refute Weapon.new(weapon_type: "槍").one_handed?
  end

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

  test "small sword is sellable like a normal unequipped weapon" do
    weapon = Weapon.new(
      name: "スモールソード",
      weapon_type: "片手直剣",
      rarity: "common",
      attack_power: 6,
      durability: 200,
      max_durability: 200,
      equipped: false
    )

    assert weapon.starter_weapon?
    assert weapon.sellable_by_player?
    assert weapon.discardable_by_player?
    assert_operator weapon.sell_price, :>, 0
  end

  test "small sword is available cheaply at weapon shops" do
    beginning_town = Location.new(name: "はじまりの街")
    hornka = Location.new(name: "ホルンカの村")

    beginning_definition = ShopCatalog.weapon_shop_weapon(beginning_town, "スモールソード")
    hornka_definition = ShopCatalog.weapon_shop_weapon(hornka, "スモールソード")

    assert_equal 35, beginning_definition.price
    assert_equal 30, hornka_definition.price
    assert_operator beginning_definition.price, :<, ShopCatalog.weapon_shop_weapon(beginning_town, "ブロンズソード").price
    assert_operator hornka_definition.price, :<, ShopCatalog.weapon_shop_weapon(hornka, "ブロンズソード").price
  end

  test "directional enhancement levels calculate their independent effects" do
    weapon = Weapon.new(
      name: "強化効果テスト剣",
      weapon_type: "片手直剣",
      attack_power: 100,
      durability: 150,
      max_durability: 100,
      enhance_limit: 13,
      sharpness_level: 2,
      quickness_level: 2,
      accuracy_level: 2,
      heaviness_level: 2,
      durability_level: 5
    )

    assert_equal 13, weapon.enhancement_level
    assert_in_delta 110.0, weapon.base_effective_attack_power, 0.0001
    assert_equal 109, weapon.effective_part_break_power
    assert_equal 150, weapon.effective_max_durability
    assert_equal 6, weapon.sword_skill_accuracy_bonus
    assert_equal 213, weapon.sword_skill_damage_multiplier(200, 4)
  end

  test "durability enhancement accumulates fractional durability savings" do
    weapon = Weapon.new(
      name: "耐久強化テスト剣",
      weapon_type: "片手直剣",
      durability: 10,
      max_durability: 10,
      durability_level: 1
    )

    2.times { weapon.apply_durability_loss!(1) }

    assert_equal 9, weapon.durability
    assert_in_delta 0.94, weapon.durability_loss_remainder.to_f, 0.001
  end
end
