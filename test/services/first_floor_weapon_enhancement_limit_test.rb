require "test_helper"

class FirstFloorWeaponEnhancementLimitTest < ActiveSupport::TestCase
  test "initial weapon has one enhancement attempt" do
    player = players(:one)
    player.weapons.destroy_all

    PlayerInitializer.choose_initial_weapon!(player, StarterWeaponCatalog.find("small_sword"))

    assert_equal 1, player.weapons.find_by!(name: "無銘の直剣").enhance_limit
  end

  test "shop weapons have at most three attempts and other first floor definitions have at most eight" do
    ShopCatalog.reload!
    sold_weapons = ShopCatalog.weapon_definitions.reject(&:production_only)
    special_weapons = ShopCatalog.weapon_definitions.select(&:production_only)

    assert sold_weapons.any?
    assert sold_weapons.all? { |weapon| weapon.enhance_limit <= 3 }
    assert sold_weapons.any? { |weapon| weapon.enhance_limit == 3 }
    assert special_weapons.all? { |weapon| weapon.enhance_limit <= 8 }

    mob_weapon_limits = []
    SimpleCsv.foreach(Rails.root.join("db", "seeds", "mob_weapons.csv")) do |row|
      mob_weapon_limits << row["enhance_limit"].to_i
    end
    assert mob_weapon_limits.all? { |limit| limit <= 8 }
  ensure
    ShopCatalog.reload!
  end

  test "first floor crafting preview caps enhancement attempts at eight" do
    player = players(:one)
    player.update!(floor: 1)
    context = BlacksmithService::Context.new(player: player, proficiency: 100)

    preview = WeaponCraftService.preview_for(
      context: context,
      weapon_type: "片手直剣",
      ore_material: "鉄鉱",
      monster_material: "ホーンラビットの角",
      support_material: "精錬石"
    )

    assert_equal :ok, preview.status
    assert_operator preview.enhance_limit_range.max, :<=, 8
  end
end
