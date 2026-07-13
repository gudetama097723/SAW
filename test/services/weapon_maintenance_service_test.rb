require "test_helper"

class WeaponMaintenanceServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    location = Location.create!(name: "整備試験の町", floor: 1, safe_area: true, has_blacksmith_facility: true)
    @player.update!(name: "整備試験者", col: 1_000, location: location)
    @skill = @player.skills.create!(name: "鍛冶", proficiency: 600, skill_exp: 274_888, skill_category: "production")
    @kit = @player.items.create!(
      name: WeaponMaintenanceService::KIT_NAME, category: "misc", quantity: 1,
      durability: 30, max_durability: 30
    )
    @weapon = @player.weapons.create!(
      name: "整備試験剣", weapon_type: "片手直剣", attack_power: 20,
      durability: 50, max_durability: 100, maintenance_level: 500
    )
  end

  test "player maintenance is free and consumes kit durability based on proficiency" do
    context = BlacksmithService.context_for(@player, mode: "player")
    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
    assert_equal 28, @kit.reload.durability
    assert_equal 1_000, @player.reload.col
    assert_operator result.skill_exp_gained, :>, 0
  end

  test "tiny repairs grant no proficiency experience" do
    @weapon.update!(durability: 99)
    context = BlacksmithService.context_for(@player, mode: "player")
    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :ok, result.status
    assert_equal 0, result.skill_exp_gained
  end

  test "player maintenance remains available while traveling without a facility" do
    destination = Location.create!(name: "整備試験の行先", floor: 1, safe_area: true)
    route = Route.create!(from_location: @player.location, to_location: destination, name: "整備試験街道")
    @player.update!(field_route: route)
    context = BlacksmithService.context_for(@player, mode: "player")

    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :ok, result.status
    assert_equal 100, @weapon.reload.durability
  end

  test "npc maintenance is rejected away from its facility" do
    @player.location.update!(has_blacksmith_facility: true)
    npc = Npc.create!(
      code: "maintenance_facility_smith", name: "整備場所試験鍛冶師", npc_type: "blacksmith",
      placement_type: "facility", facility_key: "blacksmith", location: @player.location,
      blacksmith_base_proficiency: 600, blacksmith_max_proficiency: 600
    )
    context = BlacksmithService::Context.new(player: @player, npc: npc, proficiency: 600)
    destination = Location.create!(name: "NPC整備試験の行先", floor: 1, safe_area: true)
    route = Route.create!(from_location: @player.location, to_location: destination, name: "NPC整備試験街道")
    @player.update!(field_route: route)

    result = WeaponMaintenanceService.call(player: @player, weapon: @weapon, blacksmith: context)

    assert_equal :error, result.status
    assert_includes result.message, "鍛冶設備が必要"
    assert_equal 50, @weapon.reload.durability
  end
end
