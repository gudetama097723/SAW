require "test_helper"

class WeaponMaintenanceServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    location = Location.create!(name: "整備試験の町", floor: 1, safe_area: true, has_blacksmith_facility: true)
    @player.update!(name: "整備試験者", col: 1_000, location: location)
    @npc = Npc.create!(
      code: "maintenance_service_test_smith", name: "整備試験鍛冶師", npc_type: "blacksmith",
      placement_type: "facility", facility_key: "blacksmith", location: location,
      blacksmith_base_proficiency: 600, blacksmith_max_proficiency: 600
    )
    @weapon = @player.weapons.create!(
      name: "整備試験剣", weapon_type: "片手直剣", attack_power: 20,
      durability: 50, max_durability: 100, maintenance_level: 0
    )
  end

  test "npc maintenance repairs to full and charges a fee" do
    context = BlacksmithService::Context.new(player: @player, npc: @npc, proficiency: 600)

    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
    assert_operator @player.reload.col, :<, 1_000
  end

  test "self mode via blacksmith context is rejected even with the blacksmith skill" do
    @player.skills.create!(name: "鍛冶", proficiency: 600, skill_exp: 274_888, skill_category: "production")
    context = BlacksmithService.context_for(@player, mode: "player")

    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :error, result.status
    assert_includes result.message, "携帯用の武器整備キット"
    assert_equal 50, @weapon.reload.durability
  end

  test "npc maintenance is rejected away from its facility" do
    destination = Location.create!(name: "NPC整備試験の行先", floor: 1, safe_area: true)
    route = Route.create!(from_location: @player.location, to_location: destination, name: "NPC整備試験街道")
    @player.update!(field_route: route)
    context = BlacksmithService::Context.new(player: @player, npc: @npc, proficiency: 600)

    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :error, result.status
    assert_includes result.message, "鍛冶設備が必要"
    assert_equal 50, @weapon.reload.durability
  end

  test "use_kit! heals 50 percent of max durability and consumes exactly one kit" do
    kit = @player.items.create!(name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 2)

    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
    assert_equal 1, kit.reload.quantity
  end

  test "use_kit! caps healing at the weapon's max durability" do
    @weapon.update!(durability: 90)
    @player.items.create!(name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1)

    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
  end

  test "use_kit! removes the kit once its last use is spent" do
    @player.items.create!(name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1)

    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :ok, result.status
    assert_nil @player.items.find_by(name: WeaponMaintenanceService::KIT_NAME)
  end

  test "use_kit! fails without a kit" do
    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :error, result.status
    assert_includes result.message, "武器整備キットが必要です"
    assert_equal 50, @weapon.reload.durability
  end

  test "use_kit! works without the blacksmith skill and counts toward unlocking it" do
    @player.items.create!(name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1)
    assert_nil BlacksmithService.blacksmith_skill_for(@player)

    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :ok, result.status
    assert_equal 1, @player.reload.skill_counter(WeaponMaintenanceService::KIT_USE_COUNTER_KEY)
  end

  test "use_kit! does not require being at a blacksmith facility or on any particular route" do
    @player.items.create!(name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1)
    destination = Location.create!(name: "整備キット試験の行先", floor: 1, safe_area: true)
    route = Route.create!(from_location: @player.location, to_location: destination, name: "整備キット試験街道")
    @player.update!(field_route: route)

    result = WeaponMaintenanceService.use_kit!(player: @player, weapon: @weapon)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
  end
end
