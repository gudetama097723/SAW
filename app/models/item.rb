class Item < ApplicationRecord
  belongs_to :player

  CATEGORIES = {
    "healing" => "回復アイテム",
    "gathered" => "採取アイテム",
    "drop" => "ドロップアイテム",
    "misc" => "その他"
  }.freeze

  def category_name
    CATEGORIES.fetch(category, "その他")
  end

def total_weight
  weight.to_d * quantity.to_i
end

def protected_item?
  protected_from_death_penalty? || unique_item? || quest_item? || !discardable?
end

def discardable_by_player?
  discardable? && !unique_item? && !quest_item?
end

def sellable_by_player?(confirm_unique: false)
  return false if quest_item?
  return confirm_unique if unique_item?

  true
end

def sell_price

    {
      "薬草" => 3,
      "ポーション" => 15,
      "スライムの核" => 8,
      "ホーンラビットの角" => 12,
      "変異スライムの核" => 25,
      "しなる枝" => 4
    }.fetch(name, 1)
  end
end
