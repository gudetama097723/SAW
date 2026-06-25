require "test_helper"

class FieldServiceTest < ActiveSupport::TestCase
  test "starting grassland gathering can yield poison mushrooms" do
    items = FieldService.gatherable_items_for(Route.new(name: "はじまりの草原"))

    assert_includes items, "毒キノコ"
    assert_operator items.count("毒キノコ"), :<, items.count("薬草")
  end

  test "gathering catalog loads item category from csv" do
    definition = GatheringCatalog.definitions_for(Route.new(name: "はじまりの草原")).find do |candidate|
      candidate.item_name == "毒キノコ"
    end

    assert_equal "gathered", definition.category
    assert_equal 1, definition.weight
  end
end
