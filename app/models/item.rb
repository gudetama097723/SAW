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
