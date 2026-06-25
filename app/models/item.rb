class Item < ApplicationRecord
  belongs_to :player

  CATEGORIES = {
    "healing" => "回復アイテム",
    "gathered" => "採取アイテム",
    "drop" => "ドロップアイテム",
    "misc" => "その他"
  }.freeze

  UNIQUE_ITEM_MIN_SELL_PRICE = 1000
  MIN_TASTINESS_TO_EAT = 30

  FOOD_DEFINITIONS = {
    "薬草" => {
      tastiness: 35,
      satiety_restore: 3,
      eat_effect: { "hp" => 5 }
    },
    "毒キノコ" => {
      tastiness: 50,
      satiety_restore: 5,
      eat_effect: { "statuses" => { "poison" => 3 } },
      description: "見た目で明らかに毒があるとわかるキノコ。しかし匂いは意外と美味しそう。"
    }
  }.freeze

  def category_name
    CATEGORIES.fetch(category, "その他")
  end

  def food_definition
    FOOD_DEFINITIONS[name] || {}
  end

  def food?
    self[:food] || food_definition.present?
  end

  def effective_tastiness
    value = self[:tastiness].to_i
    value.positive? ? value : food_definition.fetch(:tastiness, 0)
  end

  def effective_satiety_restore
    value = self[:satiety_restore].to_i
    value.positive? ? value : food_definition.fetch(:satiety_restore, 0)
  end

  def eat_effect_data_hash
    JSON.parse(eat_effect_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def effective_eat_effect_data
    food_definition.fetch(:eat_effect, {}).merge(eat_effect_data_hash)
  end

  def edible_by?(player)
    food? && (effective_tastiness >= MIN_TASTINESS_TO_EAT || player&.can_eat_unappetizing_food?)
  end

  def apply_food_defaults
    return unless food_definition.present?

    self.food = true if has_attribute?(:food)
    self.tastiness = food_definition[:tastiness] if has_attribute?(:tastiness)
    self.satiety_restore = food_definition[:satiety_restore] if has_attribute?(:satiety_restore)
    self.eat_effect_data = food_definition[:eat_effect].to_json if has_attribute?(:eat_effect_data)
    self.description = food_definition[:description] if has_attribute?(:description) && food_definition[:description].present?
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

    price = {
      "薬草" => 3,
      "ポーション" => 15,
      "スライムの核" => 8,
      "ホーンラビットの角" => 12,
      "変異スライムの核" => 25,
      "しなる枝" => 4
    }.fetch(name, 1)
    unique_item? ? [price, UNIQUE_ITEM_MIN_SELL_PRICE].max : price
  end
end
