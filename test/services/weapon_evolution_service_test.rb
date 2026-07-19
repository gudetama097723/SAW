require "test_helper"

class WeaponEvolutionServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    @player.items.destroy_all
    @player.weapons.destroy_all
    location = Location.create!(name: "進化試験の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    @player.update!(col: 100_000, level: 10, location: location)
    @blacksmith = Npc.create!(
      code: "evolution_test_blacksmith",
      name: "進化試験鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: @player.location,
      blacksmith_base_proficiency: 300,
      blacksmith_max_proficiency: 300
    )
    @player.npc_discoveries.create!(npc: @blacksmith, currently_available: true)
    @rule = WeaponEvolutionRule.create!(
      source_weapon_name: "進化試験元武器",
      target_weapon_name: "進化試験先武器",
      required_conditions_data: [ { "type" => "enhancement_maxed" } ].to_json,
      required_player_level: 5,
      required_smith_proficiency: 250,
      required_materials_data: { "items" => { "硬い甲殻" => 3 }, "col" => 300 }.to_json
    )
    @weapon = @player.weapons.create!(
      name: "進化試験元武器",
      weapon_type: "片手直剣",
      attack_power: 10,
      durability: 100,
      max_durability: 100,
      enhance_limit: 1,
      enhance_attempts: 1,
      sharpness_level: 1,
      critical_hit_count: 7,
      kill_count: 9,
      origin: "starter"
    )
    @player.items.create!(name: "硬い甲殻", category: "drop", quantity: 5)
  end

  test "eligible_rule_for returns nil for shop and crafted origin weapons even with a matching name" do
    @weapon.update!(origin: "shop")
    assert_nil WeaponEvolutionService.eligible_rule_for(@weapon)

    @weapon.update!(origin: "crafted")
    assert_nil WeaponEvolutionService.eligible_rule_for(@weapon)
  end

  test "eligible_rule_for returns the rule for starter, boss_drop and quest_reward origins" do
    %w[starter boss_drop quest_reward].each do |origin|
      @weapon.update!(origin: origin)
      assert_equal @rule, WeaponEvolutionService.eligible_rule_for(@weapon)
    end
  end

  test "evolve! succeeds, consumes materials and col, and resets enhancement and evolution counters" do
    before_col = @player.col

    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert_equal :ok, result.status
    assert_includes result.message, "進化試験先武器"
    @weapon.reload
    assert_equal "進化試験先武器", @weapon.name
    assert_equal 0, @weapon.enhancement_level
    assert_equal 0, @weapon.enhance_attempts
    assert_equal 0, @weapon.sharpness_level
    assert_equal 0, @weapon.critical_hit_count
    assert_equal 0, @weapon.kill_count
    assert_equal before_col - 300, @player.reload.col
    assert_equal 2, @player.items.find_by!(name: "硬い甲殻").quantity
  end

  test "evolve! is rejected when the weapon's own conditions are not met" do
    @weapon.update!(sharpness_level: 0)

    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert_equal :error, result.status
    assert_equal "進化試験元武器", @weapon.reload.name
  end

  test "evolve! is rejected when the smith's proficiency is below the requirement" do
    @blacksmith.update!(blacksmith_base_proficiency: 10, blacksmith_max_proficiency: 10)

    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert_equal :error, result.status
    assert_includes result.message, "技量が足りない"
    assert_equal "進化試験元武器", @weapon.reload.name
  end

  test "evolve! is rejected when materials or col are insufficient" do
    @player.items.find_by!(name: "硬い甲殻").update!(quantity: 1)

    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert_equal :error, result.status
    assert_includes result.message, "素材が足りません"
  end

  test "evolve! is rejected when the shop or crafted origin weapon happens to share the source name" do
    @weapon.update!(origin: "shop")

    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert_equal :error, result.status
    assert_includes result.message, "進化できる武器ではありません"
  end

  test "a multi-stage chain becomes eligible for its next rule after evolving" do
    next_rule = WeaponEvolutionRule.create!(
      source_weapon_name: "進化試験先武器",
      target_weapon_name: "進化試験最終武器",
      required_conditions_data: [ { "type" => "kills", "min" => 5 } ].to_json,
      required_player_level: 1,
      required_smith_proficiency: 0,
      required_materials_data: "{}"
    )

    WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)
    @weapon.reload
    @weapon.update!(kill_count: 5)

    assert_equal next_rule, WeaponEvolutionService.eligible_rule_for(@weapon)
    result = WeaponEvolutionService.evolve!(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)
    assert_equal :ok, result.status
    assert_equal "進化試験最終武器", @weapon.reload.name
  end

  test "quote_for reports readiness for conditions, smith proficiency, materials and col" do
    quote = WeaponEvolutionService.quote_for(@player, @weapon, blacksmith_mode: "npc", blacksmith: @blacksmith)

    assert quote.conditions_met
    assert quote.smith_ready
    assert quote.materials_ready
    assert quote.col_ready
    assert quote.executable?
  end
end
