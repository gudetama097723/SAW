require "test_helper"

class WeaponEvolutionTest < ActionDispatch::IntegrationTest
  setup do
    @location = Location.create!(name: "進化統合試験の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    @user = User.create!(username: "weapon_evolution_#{SecureRandom.hex(4)}", password: "password")
    @player = Player.create!(user: @user, name: "進化統合試験", hp: 100, max_hp: 100, col: 1_000, level: 10, floor: 1, location: @location, current_time: 600)
    @player.town_discovery_for.update!(found_blacksmith: true)
    @blacksmith = Npc.create!(
      code: "evolution_integration_blacksmith",
      name: "進化統合試験鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: @location,
      blacksmith_base_proficiency: 300,
      blacksmith_max_proficiency: 300
    )
    @player.npc_discoveries.create!(npc: @blacksmith, currently_available: true)
    WeaponEvolutionRule.create!(
      source_weapon_name: "統合試験元武器",
      target_weapon_name: "統合試験先武器",
      required_conditions_data: [ { "type" => "enhancement_maxed" } ].to_json,
      required_player_level: 5,
      required_smith_proficiency: 250,
      required_materials_data: "{}"
    )
    @weapon = @player.weapons.create!(
      name: "統合試験元武器", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100,
      enhance_limit: 1, enhance_attempts: 1, sharpness_level: 1, origin: "starter"
    )
    post login_path, params: { username: @user.username, password: "password" }
  end

  test "shop origin weapons sharing the source name are not offered for evolution" do
    @weapon.update!(origin: "shop")

    get game_path, params: { panel: "blacksmith", blacksmith_menu: "evolve" }

    assert_response :success
    assert_not_includes response.body, "統合試験元武器"
  end

  test "evolve requires confirmation before executing" do
    post evolve_weapon_path, params: { weapon_id: @weapon.id }

    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", weapon_id: @weapon.id, smith_mode: nil)
    assert_equal "統合試験元武器", @weapon.reload.name
  end

  test "evolve succeeds once confirmed and eligible" do
    post evolve_weapon_path, params: { weapon_id: @weapon.id, confirm_evolve: "1" }

    assert_redirected_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", smith_mode: nil)
    assert_equal "統合試験先武器", @weapon.reload.name
  end
end
