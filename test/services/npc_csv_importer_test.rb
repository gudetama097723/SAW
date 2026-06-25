require "test_helper"

class NpcCsvImporterTest < ActiveSupport::TestCase
  test "imports npc master data from csv" do
    location = Location.create!(name: "テスト用の町", floor: 1, danger_level: 0, safe_area: true)
    path = Rails.root.join("tmp", "test_npcs.csv")
    File.write(
      path,
      [
        "code,name,npc_type,placement_type,location,route,field_area,facility_key,dungeon_key,position_key,sort_order,active,description,metadata_json,discovery_rate,repeat_discovery_required,discovery_conditions_json",
        "test_guide,テスト案内人,guide,town,#{location.name},,,,,town_square,1,true,テスト用,{},35,true,\"{\"\"level\"\":{\"\"min\"\":2}}\""
      ].join("\n")
    )

    result = NpcCsvImporter.new(path).import!
    npc = Npc.find_by!(code: "test_guide")

    assert_equal 1, result.created
    assert_equal "テスト案内人", npc.name
    assert_equal location, npc.location
    assert_equal "town", npc.placement_type
    assert_equal 35, npc.discovery_rate
    assert npc.repeat_discovery_required?
    assert_equal 2, npc.discovery_conditions.dig("level", "min")
  ensure
    File.delete(path) if path && File.exist?(path)
  end
end
