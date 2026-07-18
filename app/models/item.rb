class Item < ApplicationRecord
  belongs_to :player

  CATEGORIES = {
    "healing" => "回復アイテム",
    "gathered" => "採取アイテム",
    "drop" => "ドロップアイテム",
    "valuable" => "換金アイテム",
    "misc" => "その他"
  }.freeze

  UNIQUE_ITEM_MIN_SELL_PRICE = 1000
  MIN_TASTINESS_TO_EAT = 30
  MAINTENANCE_KIT_NAME = "武器整備キット"

  SELL_PRICES = {
    "薬草" => 3,
    "毒キノコ" => 2,
    "しなる枝" => 4,
    "ポーション" => 15,
    "解毒ポーション" => 20,
    "火傷治し" => 20,
    "持ち運びテント" => 60,
    "上等な持ち運びテント" => 140,
    "高級持ち運びテント" => 300,
    "スライムの粘液" => 4,
    "スライムの欠片" => 5,
    "上質なスライムの粘液" => 12,
    "スライムコア" => 28,
    "スライムの核" => 10,
    "ホーンラビットの毛皮" => 5,
    "ホーンラビットの肉" => 6,
    "ホーンラビットの角" => 12,
    "上質な毛皮" => 18,
    "白銀の角" => 42,
    "変異スライムの粘液" => 9,
    "硬質ゼリー片" => 18,
    "変異スライムの核" => 35,
    "コボルドの牙" => 14,
    "コボルドの布切れ" => 6,
    "歩哨の徽章" => 30,
    "硬い甲殻" => 16,
    "厚い甲殻" => 30,
    "蟹の脚殻" => 18,
    "小さな魔石" => 45,
    "薄羽蜂の針" => 14,
    "薄羽蜂の羽" => 10,
    "薄羽蜂の外殻" => 22,
    "野猪の毛皮" => 12,
    "丈夫な野猪革" => 28,
    "野猪の牙" => 18,
    "野猪の肉" => 8,
    "コボルドの短刃片" => 20,
    "斥候の徽章" => 40,
    "群狼の牙" => 24,
    "群狼の毛皮" => 22,
    "群狼の爪" => 32,
    "狼王の牙" => 220,
    "蒼狼の牙" => 600,
    "錆びた銅貨" => 25,
    "磨かれた銀貨" => 90,
    "古い金貨" => 250,
    "小さな晶貨" => 500,
    "砥石片" => 6,
    "亀甲片" => 24,
    "砂搔き鼬の毛皮" => 16,
    "磨り減った認識票" => 200,
    "鉄鉱" => 10,
    "鋭鉄鉱" => 18,
    "黒鋼鉱" => 60
  }.freeze

  VALUABLE_DESCRIPTIONS = {
    "錆びた銅貨" => "古い時代の銅貨。店で換金する以外の用途はない。",
    "磨かれた銀貨" => "丁寧に磨かれた銀貨。換金用として扱われる。",
    "古い金貨" => "今は流通していない金貨。高値で換金できる。",
    "小さな晶貨" => "透明な結晶を貨幣状に削ったもの。希少な換金品。",
    "磨り減った認識票" => "岩塊の核にあった、磨り減って文字の読めない認識票。換金する以外に使い道はない。"
  }.freeze

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

  TENT_DEFINITIONS = {
    "持ち運びテント" => { encounter_multiplier: 0.7, weight: 8.to_d, price: 120 },
    "上等な持ち運びテント" => { encounter_multiplier: 0.5, weight: 10.to_d, price: 280 },
    "高級持ち運びテント" => { encounter_multiplier: 0.3, weight: 12.to_d, price: 600 }
  }.freeze

  def category_name
    CATEGORIES.fetch(category, "その他")
  end

  def maintenance_kit?
    name == MAINTENANCE_KIT_NAME
  end

  def effective_max_durability
    return 30 if maintenance_kit? && max_durability.to_i <= 0

    max_durability.to_i
  end

  def effective_durability
    return effective_max_durability if maintenance_kit? && durability.to_i <= 0

    durability.to_i
  end

  def food_definition
    FOOD_DEFINITIONS[name] || {}
  end

  def tent_definition
    TENT_DEFINITIONS[name] || {}
  end

  def portable_tent?
    tent_definition.present?
  end

  def tent_encounter_multiplier
    tent_definition.fetch(:encounter_multiplier, 1.0).to_f
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

  def apply_item_defaults
    apply_food_defaults
    if valuable?
      self.description = valuable_description if has_attribute?(:description) && description.blank?
      self.weight = 0.to_d if has_attribute?(:weight)
    end
    return unless tent_definition.present?

    self.category = "misc" if category.blank?
    self.weight = tent_definition[:weight] if has_attribute?(:weight)
  end

  def valuable?
    category == "valuable"
  end

  def valuable_description
    VALUABLE_DESCRIPTIONS.fetch(name, "店で換金するためのアイテム。")
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
    price = SELL_PRICES.fetch(name, valuable? ? 10 : 1)
    unique_item? ? [price, UNIQUE_ITEM_MIN_SELL_PRICE].max : price
  end
end
