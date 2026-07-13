require "test_helper"

class WeaponCraftServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
    location = Location.create!(name: "生産試験工房", floor: 1, danger_level: 0, safe_area: true, has_blacksmith_facility: true)
    @player.update!(name: "鍛冶試験者", col: 5_000, location: location)
    @skill = @player.skills.create!(name: "鍛冶", proficiency: 100, skill_exp: 31_608, skill_category: "production")
    add_item("鉄鉱", 3)
    add_item("ホーンラビットの角", 1)
    add_item("精錬石", 1)
  end

  test "player crafting consumes three material slots without a fee and creates variable crafted stats" do
    context = BlacksmithService.context_for(@player, mode: "player")

    result = WeaponCraftService.call(
      player: @player, blacksmith: context, weapon_type: "片手直剣",
      ore_material: "鉄鉱", monster_material: "ホーンラビットの角",
      support_material: "精錬石", rng: Random.new(1234)
    )

    assert_equal :ok, result.status
    assert result.weapon.crafted?
    assert_equal "片手直剣", result.weapon.weapon_type
    assert_equal 5_000, @player.reload.col
    assert_equal 4, result.weapon.craft_details.fetch("qualities").size
    assert_nil @player.items.find_by(name: "鉄鉱")
    assert_operator @skill.reload.skill_exp, :>, 31_608
  end

  test "processing level blocks materials above the blacksmith proficiency before consumption" do
    add_item("黒鋼鉱", 3)
    context = BlacksmithService.context_for(@player, mode: "player")

    result = WeaponCraftService.call(
      player: @player, blacksmith: context, weapon_type: "片手直剣",
      ore_material: "黒鋼鉱", monster_material: "ホーンラビットの角",
      support_material: "精錬石"
    )

    assert_equal :error, result.status
    assert_includes result.message, "技量が足りない"
    assert_equal 3, @player.items.find_by(name: "黒鋼鉱").quantity
  end

  test "crafting is rejected without a blacksmith facility for both player and npc contexts" do
    player_context = BlacksmithService.context_for(@player, mode: "player")
    npc = Npc.create!(
      code: "craft_remote_smith", name: "生産場所試験鍛冶師", npc_type: "blacksmith",
      placement_type: "facility", facility_key: "blacksmith", location: @player.location,
      blacksmith_base_proficiency: 100, blacksmith_max_proficiency: 100
    )
    npc_context = BlacksmithService::Context.new(player: @player, npc: npc, proficiency: 100)
    @player.location.update!(has_blacksmith_facility: false)

    [ player_context, npc_context ].each do |context|
      result = WeaponCraftService.call(
        player: @player, blacksmith: context, weapon_type: "片手直剣",
        ore_material: "鉄鉱", monster_material: "ホーンラビットの角",
        support_material: "精錬石"
      )
      assert_equal :error, result.status
      assert_includes result.message, "鍛冶設備が必要"
    end
  end

  test "an npc blacksmith from another location cannot be used" do
    remote_location = Location.create!(name: "遠隔鍛冶師の町", floor: 1, safe_area: true, has_blacksmith_facility: true)
    npc = Npc.create!(
      code: "remote_craft_smith", name: "遠隔鍛冶師", npc_type: "blacksmith",
      placement_type: "facility", facility_key: "blacksmith", location: remote_location,
      blacksmith_base_proficiency: 100, blacksmith_max_proficiency: 100
    )
    context = BlacksmithService::Context.new(player: @player, npc: npc, proficiency: 100)

    result = WeaponCraftService.call(
      player: @player, blacksmith: context, weapon_type: "片手直剣",
      ore_material: "鉄鉱", monster_material: "ホーンラビットの角",
      support_material: "精錬石"
    )

    assert_equal :error, result.status
    assert_includes result.message, "その鍛冶師を利用できない"
  end

  private

  def add_item(name, quantity)
    @player.items.create!(name: name, category: "drop", quantity: quantity)
  end
end
