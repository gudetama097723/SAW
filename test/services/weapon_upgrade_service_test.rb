require "test_helper"

class WeaponUpgradeServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    @player.items.destroy_all
    @player.weapons.destroy_all
    location = Location.create!(name: "強化試験の町", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    @player.update!(col: 100_000, location: location)
    @blacksmith = Npc.create!(
      code: "upgrade_test_blacksmith",
      name: "強化試験鍛冶師",
      npc_type: "blacksmith",
      placement_type: "facility",
      facility_key: "blacksmith",
      location: @player.location,
      blacksmith_base_proficiency: 40,
      blacksmith_max_proficiency: 100
    )
    @discovery = @player.npc_discoveries.create!(npc: @blacksmith, currently_available: true)
    @weapon = @player.weapons.create!(
      name: "強化テスト剣",
      weapon_type: "片手直剣",
      attack_power: 100,
      durability: 100,
      max_durability: 100,
      enhance_limit: 3,
      enhancement_difficulty: 1.0
    )
    @player.items.create!(name: "硬い甲殻", category: "drop", quantity: 10)
  end

  test "successful directional enhancement consumes resources and raises the selected level" do
    quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, blacksmith: @blacksmith)
    before_col = @player.col
    before_time = @player.current_time
    stub_upgrade_roll(0) do
      result = WeaponUpgradeService.upgrade!(@player, @weapon, "S")

      assert_equal :ok, result.status
      assert_includes result.message, "強化成功"
      assert_includes result.message, "鋭さ +1"
      assert_not_includes result.message, "S +1"
    end

    @weapon.reload
    assert_equal 1, @weapon.sharpness_level
    assert_equal 1, @weapon.enhancement_level
    assert_equal 1, @weapon.enhance_attempts
    assert_equal before_col - quote.required_col, @player.reload.col
    assert_equal 8, @player.items.find_by!(name: "硬い甲殻").quantity
    assert_equal before_time, @player.current_time
  end

  test "failed enhancement still consumes its attempt and resources" do
    quote = WeaponUpgradeService.quote_for(@weapon, "D", player: @player, blacksmith: @blacksmith)
    before_col = @player.col
    stub_upgrade_roll(99) do
      result = WeaponUpgradeService.upgrade!(@player, @weapon, "D")

      assert_equal :ok, result.status
      assert_includes result.message, "強化失敗"
    end

    @weapon.reload
    assert_equal 0, @weapon.durability_level
    assert_equal 0, @weapon.enhancement_level
    assert_equal 1, @weapon.enhance_attempts
    assert_equal before_col - quote.required_col, @player.reload.col
  end

  test "player blacksmithing charges no fee and grants shared blacksmith experience" do
    skill = @player.skills.create!(
      name: "鍛冶", proficiency: 100, skill_exp: 31_608, skill_category: "production"
    )
    before_col = @player.col

    stub_upgrade_roll(0) do
      result = WeaponUpgradeService.upgrade!(@player, @weapon, "S", blacksmith_mode: "player")
      assert_equal :ok, result.status
    end

    assert_equal before_col, @player.reload.col
    assert_equal 1, @weapon.reload.sharpness_level
    assert_operator skill.reload.skill_exp, :>, 31_608
  end

  test "cost and material quantity use total enhancement level and decimal difficulty" do
    @weapon.update!(
      enhancement_difficulty: 1.8,
      enhance_attempts: 4,
      sharpness_level: 3,
      quickness_level: 1,
      enhancement_level: 4
    )

    quote = WeaponUpgradeService.quote_for(@weapon, "A", player: @player, blacksmith: @blacksmith)

    assert_equal 5, quote.target_level
    assert_equal 10_800, quote.required_col
    assert_equal "中級", quote.material_rank
    assert_equal({ "ホーンラビットの角" => 13 }, quote.required_materials)
    assert_equal 2, quote.blacksmith_bonus
  end

  test "npc proficiency reduces only the points needed for one hundred percent in ten point steps" do
    @weapon.update!(enhance_limit: 8, enhance_attempts: 7, sharpness_level: 7, enhancement_level: 7)
    novice = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 0)
    below_step = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 9)
    first_step = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 10)
    master = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 1000)

    novice_quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: novice)
    below_step_quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: below_step)
    first_step_quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: first_step)
    master_quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: master)

    assert_equal 80, novice_quote.required_points
    assert_equal 80, master_quote.required_points
    assert_equal 520, novice_quote.guaranteed_points
    assert_equal 520, below_step_quote.guaranteed_points
    assert_equal 518, first_step_quote.guaranteed_points
    assert_equal 2, first_step_quote.guaranteed_point_reduction
    assert_equal 0.005, first_step_quote.proficiency_reduction_rate
    assert_equal 260, master_quote.guaranteed_points
    assert_equal 260, master_quote.guaranteed_point_reduction
  end

  test "player blacksmith proficiency uses the same guaranteed point reduction" do
    @player.skills.create!(name: "鍛冶", proficiency: 1000, skill_exp: 31_608, skill_category: "production")
    context = BlacksmithService.context_for(@player, mode: "player")

    quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: context)

    assert context.player?
    assert_equal 2, quote.required_points
    assert_equal 7, quote.guaranteed_points
    assert_equal 6, quote.guaranteed_point_reduction
    assert_equal 0, quote.required_col
  end

  test "first floor plus eight reaches one hundred percent near five hundred points at proficiency one hundred" do
    @weapon.update!(enhance_limit: 8, enhance_attempts: 7, sharpness_level: 7, enhancement_level: 7)
    context = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 100)

    quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: context)

    assert_equal 8, quote.target_level
    assert_equal 80, quote.required_points
    assert_equal 520, quote.base_guaranteed_points
    assert_equal 494, quote.guaranteed_points
  end

  test "later floors retain the standard guarantee multiplier" do
    @player.update!(floor: 2)
    context = BlacksmithService::Context.new(player: @player, npc: @blacksmith, proficiency: 0)

    quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, context: context)

    assert_equal 2, quote.required_points
    assert_equal 128, quote.base_guaranteed_points
    assert_equal 128, quote.guaranteed_points
  end

  test "material options include only owned materials the blacksmith can process" do
    @player.items.create!(name: "コボルドの牙", category: "drop", quantity: 1)
    @player.items.create!(name: "狼王の牙", category: "drop", quantity: 1)
    @player.items.create!(name: "小さな魔石", category: "drop", quantity: 1)

    options = WeaponUpgradeService.material_options_for(@player, "S", "low", proficiency: 40)

    assert_equal [ "硬い甲殻", "コボルドの牙" ], options.map { |material, _owned| material.name }
    assert_equal [ 1, 2 ], options.map { |material, _owned| material.enhancement_points }
    assert_equal [ 10, 1 ], options.map(&:last)
  end

  test "success rate rises continuously with invested points and reaches one hundred percent" do
    @player.items.find_by!(name: "硬い甲殻").update!(quantity: 200)

    base_quote = WeaponUpgradeService.quote_for(@weapon, "S", player: @player, blacksmith: @blacksmith)
    doubled_quote = WeaponUpgradeService.quote_for(
      @weapon, "S", player: @player, blacksmith: @blacksmith,
      material_quantities: { "硬い甲殻" => 4 }
    )
    guaranteed_quote = WeaponUpgradeService.quote_for(
      @weapon, "S", player: @player, blacksmith: @blacksmith,
      material_quantities: { "硬い甲殻" => 13 }
    )

    assert_equal 95, base_quote.success_rate
    assert_equal({ "硬い甲殻" => 2 }, base_quote.required_materials)
    assert_operator doubled_quote.success_rate, :>, base_quote.success_rate
    assert_operator doubled_quote.success_rate, :<, 100.0
    assert_equal 100.0, guaranteed_quote.success_rate

    stub_upgrade_roll(99) do
      result = WeaponUpgradeService.upgrade!(
        @player, @weapon, "S", material_quantities: { "硬い甲殻" => 13 }
      )
      assert_equal :ok, result.status
      assert_includes result.message, "強化成功"
    end

    assert_equal 187, @player.items.find_by!(name: "硬い甲殻").quantity
  end

  test "each doubling of enhancement points progressively compresses failure rate" do
    rates = [ 2, 3, 4, 5, 6, 8, 13 ].map do |quantity|
      WeaponUpgradeService.quote_for(
        @weapon, "S", player: @player, blacksmith: @blacksmith,
        material_quantities: { "硬い甲殻" => quantity }
      ).success_rate
    end

    assert_equal rates.sort, rates
    assert_equal 95.0, rates.first
    assert_equal 100.0, rates.last
    assert rates.each_cons(2).all? { |left, right| right > left }
  end

  test "high quality and mixed materials satisfy the same enhancement point requirement with fewer items" do
    @player.items.create!(name: "コボルドの牙", category: "drop", quantity: 2)
    @player.items.create!(name: "小さな魔石", category: "drop", quantity: 1)

    mixed = WeaponUpgradeService.quote_for(
      @weapon, "S", player: @player, blacksmith: @blacksmith,
      material_quantities: { "硬い甲殻" => 1, "コボルドの牙" => 1 }
    )
    rare = WeaponUpgradeService.quote_for(
      @weapon, "S", player: @player, blacksmith: @blacksmith,
      material_quantities: { "小さな魔石" => 1 }
    )

    assert_equal 2, mixed.required_points
    assert_equal 3, mixed.invested_points
    assert mixed.points_satisfied?
    assert_equal({ "硬い甲殻" => 1, "コボルドの牙" => 1 }, mixed.required_materials)
    assert_equal 25, rare.invested_points
    assert rare.points_satisfied?
    assert_equal 1, rare.required_materials.values.sum
  end

  test "enhancement has no fixed hard shell requirement outside the selected point materials" do
    @player.items.create!(name: "コボルドの牙", category: "drop", quantity: 1)
    hard_shell_quantity = @player.items.find_by!(name: "硬い甲殻").quantity

    stub_upgrade_roll(0) do
      result = WeaponUpgradeService.upgrade!(
        @player, @weapon, "S", material_quantities: { "コボルドの牙" => 1 }
      )

      assert_equal :ok, result.status
      assert_includes result.message, "強化成功"
    end

    assert_nil @player.items.find_by(name: "コボルドの牙")
    assert_equal hard_shell_quantity, @player.items.find_by!(name: "硬い甲殻").quantity
  end

  test "enhancement rejects a material mixture below the required points" do
    quote = WeaponUpgradeService.quote_for(
      @weapon, "S", player: @player, blacksmith: @blacksmith,
      material_quantities: { "硬い甲殻" => 1 }
    )

    assert_equal 1, quote.point_shortage
    result = WeaponUpgradeService.upgrade!(
      @player, @weapon, "S", material_quantities: { "硬い甲殻" => 1 }
    )
    assert_equal :error, result.status
    assert_includes result.message, "強化ポイントが1pt不足"
    assert_equal 0, @weapon.reload.enhance_attempts
  end

  test "an exhausted weapon cannot consume more resources" do
    @weapon.update!(enhance_attempts: 3)
    before_col = @player.col
    before_quantity = @player.items.find_by!(name: "硬い甲殻").quantity

    result = WeaponUpgradeService.upgrade!(@player, @weapon, "S")

    assert_equal :error, result.status
    assert_equal before_col, @player.reload.col
    assert_equal before_quantity, @player.items.find_by!(name: "硬い甲殻").quantity
  end

  test "enhancement is rejected without a facility for player and npc blacksmithing" do
    @player.skills.create!(name: "鍛冶", proficiency: 100, skill_exp: 31_608, skill_category: "production")
    @player.location.update!(has_blacksmith_facility: false)
    before_quantity = @player.items.find_by!(name: "硬い甲殻").quantity

    %w[npc player].each do |mode|
      result = WeaponUpgradeService.upgrade!(@player, @weapon, "S", blacksmith_mode: mode)
      assert_equal :error, result.status
      assert_includes result.message, "鍛冶設備が必要"
    end
    assert_equal before_quantity, @player.items.find_by!(name: "硬い甲殻").quantity
  end

  private

  def stub_upgrade_roll(value)
    WeaponUpgradeService.singleton_class.define_method(:rand) { |_range| value }
    yield
  ensure
    WeaponUpgradeService.singleton_class.remove_method(:rand)
  end
end
