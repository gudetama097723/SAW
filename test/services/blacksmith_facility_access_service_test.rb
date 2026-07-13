require "test_helper"

class BlacksmithFacilityAccessServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    @town = Location.create!(name: "設備判定の町", floor: 1, safe_area: true, has_blacksmith_facility: true)
    @destination = Location.create!(name: "設備判定の隣町", floor: 1, safe_area: true, has_blacksmith_facility: false)
    @player.update!(location: @town, field_route: nil)
  end

  test "facility is available only while actually staying at its location" do
    assert BlacksmithFacilityAccessService.available?(@player)

    route = Route.create!(from_location: @town, to_location: @destination, name: "設備のない街道")
    @player.update!(field_route: route)

    assert_not BlacksmithFacilityAccessService.available?(@player)
  end

  test "an npc blacksmith must belong to the current facility" do
    local = create_blacksmith("local_facility_smith", @town)
    remote = create_blacksmith("remote_facility_smith", @destination)

    assert BlacksmithFacilityAccessService.npc_available?(@player, local)
    assert_not BlacksmithFacilityAccessService.npc_available?(@player, remote)
  end

  private

  def create_blacksmith(code, location)
    Npc.create!(
      code: code, name: code, npc_type: "blacksmith", placement_type: "facility",
      facility_key: "blacksmith", location: location,
      blacksmith_base_proficiency: 100, blacksmith_max_proficiency: 100
    )
  end
end
