require "test_helper"

class ItemTest < ActiveSupport::TestCase
  test "unique item cannot be discarded and sells for a high price after confirmation" do
    item = items(:one)
    item.update!(unique_item: true, discardable: false)

    assert_not item.discardable_by_player?
    assert_not item.sellable_by_player?
    assert item.sellable_by_player?(confirm_unique: true)
    assert_operator item.sell_price, :>=, Item::UNIQUE_ITEM_MIN_SELL_PRICE
  end

  test "boss drop rewards become protected unique items" do
    player = players(:one)

    ExplorationRewardService.apply_reward!(
      player,
      {
        "items" => [
          { "name" => "唯一の牙", "quantity" => 1, "category" => "drop" },
          { "name" => "ポーション", "quantity" => 1, "category" => "healing" }
        ]
      },
      unique_drops: true
    )

    unique_drop = player.items.find_by!(name: "唯一の牙")
    potion = player.items.find_by!(name: "ポーション")

    assert unique_drop.unique_item?
    assert_not unique_drop.discardable?
    assert unique_drop.protected_from_death_penalty?
    assert_not potion.unique_item?
  end

  test "herb is food and restores hp and satiety when eaten" do
    player = players(:one)
    player.update!(hp: 1, max_hp: 100, satiety: 50)
    herb = player.items.create!(name: "薬草", category: "gathered", quantity: 1)
    herb.apply_food_defaults
    herb.save!

    result = ItemService.eat_item!(player, herb)

    assert_equal :ok, result.status
    assert_equal 6, player.reload.hp
    assert_equal 53, player.satiety.to_i
    assert_nil Item.find_by(id: herb.id)
  end

  test "food cannot be eaten when satiety would exceed max" do
    player = players(:one)
    player.update!(satiety: 98)
    herb = player.items.create!(name: "薬草", category: "gathered", quantity: 1)
    herb.apply_food_defaults
    herb.save!

    result = ItemService.eat_item!(player, herb)

    assert_equal :error, result.status
    assert_equal "これ以上は食べられそうにない。", result.message
    assert_equal 1, herb.reload.quantity
  end

  test "low tastiness food requires a special skill to eat" do
    player = players(:one)
    food = player.items.create!(
      name: "苦い根",
      category: "gathered",
      quantity: 1,
      food: true,
      tastiness: 20,
      satiety_restore: 2
    )

    assert_not food.edible_by?(player)

    player.skills.create!(name: "悪食", proficiency: 0, skill_exp: 0)

    assert food.edible_by?(player)
  end

  test "poison mushroom is tasty food that applies poison when eaten" do
    player = players(:one)
    player.update!(satiety: 50, status_values: "{}")
    mushroom = ItemService.add_item!(player, "毒キノコ", "gathered")
    mushroom.save!

    result = ItemService.eat_item!(player, mushroom)

    assert_equal :ok, result.status
    assert_equal 55, player.reload.satiety.to_i
    assert_equal 3, player.status_value_data["poison"]
    assert_equal 50, mushroom.effective_tastiness
    assert_equal "見た目で明らかに毒があるとわかるキノコ。しかし匂いは意外と美味しそう。", mushroom.description
  end
end
