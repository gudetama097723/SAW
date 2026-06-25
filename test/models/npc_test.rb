require "test_helper"

class NpcTest < ActiveSupport::TestCase
  test "town placement requires a location" do
    npc = Npc.new(code: "guide", name: "案内人", placement_type: "town")

    assert_not npc.valid?
    assert_includes npc.errors[:location], "must exist for town placement"
  end

  test "facility placement requires a location and facility key" do
    npc = Npc.new(code: "innkeeper", name: "宿屋の主人", placement_type: "facility", location: locations(:one))

    assert_not npc.valid?
    assert_includes npc.errors[:facility_key], "must exist for facility placement"
  end

  test "field area placement requires a field area" do
    npc = Npc.new(code: "scout", name: "斥候", placement_type: "field_area")

    assert_not npc.valid?
    assert_includes npc.errors[:field_area], "must exist for field area placement"
  end

  test "dungeon placement requires a dungeon key" do
    npc = Npc.new(code: "sealed_gatekeeper", name: "封印門の番人", placement_type: "dungeon")

    assert_not npc.valid?
    assert_includes npc.errors[:dungeon_key], "must exist for dungeon placement"
  end
end
