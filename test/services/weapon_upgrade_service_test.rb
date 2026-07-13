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
