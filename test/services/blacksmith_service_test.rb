require "test_helper"

class BlacksmithServiceTest < ActiveSupport::TestCase
  test "recommended floor caps anchor floor one at 100 and floor fifty at 800" do
    assert_equal 100, BlacksmithService.proficiency_cap_for_floor(1)
    assert_equal 800, BlacksmithService.proficiency_cap_for_floor(50)
  end

  test "floor cap tops out at 1000 by floor eighty and stays clamped beyond it" do
    assert_equal 1000, BlacksmithService.proficiency_cap_for_floor(80)
    assert_equal 1000, BlacksmithService.proficiency_cap_for_floor(100)
  end

  test "tier_name_for matches the named proficiency bands used for blacksmith skill labels" do
    assert_equal "駆け出しの鍛冶師", BlacksmithService.tier_name_for(0)
    assert_equal "駆け出しの鍛冶師", BlacksmithService.tier_name_for(249)
    assert_equal "腕利きの鍛冶師", BlacksmithService.tier_name_for(250)
    assert_equal "熟練の鍛冶師", BlacksmithService.tier_name_for(500)
    assert_equal "名工", BlacksmithService.tier_name_for(800)
    assert_equal "名工", BlacksmithService.tier_name_for(1000)
  end

  test "proficiency and success bonus include player specific quest growth" do
    player = players(:one)
    location = Location.create!(name: "鍛冶熟練度試験の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    player.update!(location: location)
    blacksmith = Npc.create!(
      code: "blacksmith_service_test",
      name: "熟練度試験鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: location,
      blacksmith_base_proficiency: 30,
      blacksmith_max_proficiency: 100
    )
    discovery = player.npc_discoveries.create!(npc: blacksmith)
    discovery.gain_blacksmith_proficiency!(50)

    assert_equal blacksmith, BlacksmithService.current_for(player)
    assert_equal 80, BlacksmithService.proficiency_for(player, blacksmith)
    assert_equal 4, BlacksmithService.success_bonus_for(player, blacksmith)
  end

  test "npc mode falls back to facility default context when no npc blacksmith exists" do
    player = players(:one)
    location = Location.create!(name: "施設標準鍛冶試験の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    player.update!(location: location, field_route: nil)

    context = BlacksmithService.context_for(player, mode: "npc")

    assert context.facility?
    assert_not context.player?
    assert_not context.npc?
    assert_equal "鍛冶屋", context.name
    assert_equal 1.0, context.fee_multiplier(:maintenance)
    assert_equal BlacksmithService.proficiency_cap_for_floor(location.floor), context.proficiency
  end
end
