require "test_helper"

class BlacksmithServiceTest < ActiveSupport::TestCase
  test "recommended floor caps anchor floor one at 100 and floor fifty at 800" do
    assert_equal 100, BlacksmithService.proficiency_cap_for_floor(1)
    assert_equal 800, BlacksmithService.proficiency_cap_for_floor(50)
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
end
