class ItemService
  POTION_PRICE = 50
  POTION_PRODUCTION_COST = 20
  POTION_HEAL = 100
  HERBS_PER_POTION = 10
  STATUS_CURE_ITEMS = {
    "解毒ポーション" => "poison",
    "火傷治し" => "burn"
  }.freeze

  Result = Struct.new(:status, :message, :item, keyword_init: true)

  def self.add_item!(player, name, category, quantity = 1, unique: false)
    item = player.items.find_or_create_by!(name: name, category: category) do |new_item|
      new_item.quantity = 0
      new_item.apply_item_defaults
    end
    item.quantity = item.quantity.to_i + quantity.to_i
    item.apply_item_defaults
    if unique
      item.unique_item = true
      item.discardable = false
      item.protected_from_death_penalty = true
    end
    item
  end

  def self.buy_shop_item!(player, item_name, quantity: 1)
    quantity = normalized_quantity(quantity)
    shop_item = ShopCatalog.item_shop_item(player.location, item_name)
    return Result.new(status: :error, message: "この町では#{item_name}を購入できません。") unless shop_item
    total_price = shop_item.price * quantity
    return Result.new(status: :error, message: "コルが足りません。#{item_name}は#{quantity}個で#{total_price}コルです。") if player.col.to_i < total_price

    player.col = player.col.to_i - total_price
    player.advance_time!(5 * quantity)
    item = add_item!(player, shop_item.item_name, shop_item.category, quantity)

    ActiveRecord::Base.transaction do
      player.save!
      item.save!
    end

    Result.new(status: :ok, message: "道具屋で#{shop_item.item_name}を#{quantity}個購入した。#{total_price}コル支払った。", item: item)
  end

  def self.buy_potion!(player)
    buy_shop_item!(player, "ポーション")
  end

  def self.produce_potion!(player, quantity: 1)
    quantity = normalized_quantity(quantity)
    herb = player.items.find_by(name: "薬草", category: "gathered") || player.items.find_by(name: "薬草")
    required_herbs = HERBS_PER_POTION * quantity
    total_cost = POTION_PRODUCTION_COST * quantity
    if (herb&.quantity || 0).to_i < required_herbs
      return Result.new(status: :error, message: "薬草が足りません。ポーション#{quantity}本の生産には薬草#{required_herbs}個が必要です。")
    end

    if player.col.to_i < total_cost
      return Result.new(status: :error, message: "コルが足りません。ポーション#{quantity}本の生産には#{total_cost}コル必要です。")
    end

    herb.quantity -= required_herbs
    player.col = player.col.to_i - total_cost
    player.advance_time!(15 * quantity)
    potion = add_item!(player, "ポーション", "healing", quantity)

    ActiveRecord::Base.transaction do
      herb.quantity.to_i <= 0 ? herb.destroy! : herb.save!
      potion.save!
      player.save!
    end

    Result.new(status: :ok, message: "薬草#{required_herbs}個と#{total_cost}コルでポーションを#{quantity}本生産した。", item: potion)
  end

  def self.sell_item!(player, item, quantity: 1, confirm_unique: false)
    return Result.new(status: :error, message: "売却できるアイテムがありません。") unless item&.quantity.to_i.positive?
    return Result.new(status: :error, message: "このアイテムは売却できません。") unless item.sellable_by_player?(confirm_unique: confirm_unique)

    quantity = [[quantity.to_i, 1].max, item.quantity.to_i].min
    price = item.sell_price * quantity
    item.quantity -= quantity
    player.col = player.col.to_i + price
    player.advance_time!(5)

    ActiveRecord::Base.transaction do
      item.quantity.to_i <= 0 ? item.destroy! : item.save!
      player.save!
    end

    Result.new(status: :ok, message: "#{item.name}を#{quantity}個、#{price}コルで売却した。")
  end

  def self.consume_healing_potion!(player)
    potion = player.items.find_by(name: "ポーション", category: "healing") || player.items.find_by(name: "ポーション")
    return Result.new(status: :error, message: "ポーションを持っていません。") unless potion&.quantity.to_i.positive?

    potion.quantity -= 1
    player.hp = [player.hp.to_i + POTION_HEAL, player.effective_max_hp].min

    ActiveRecord::Base.transaction do
      potion.quantity.to_i <= 0 ? potion.destroy! : potion.save!
      player.save!
    end

    Result.new(status: :ok, message: "ポーションを使った。HPが#{POTION_HEAL}回復した。")
  end

  def self.consume_status_cure!(player, item_name)
    status = STATUS_CURE_ITEMS[item_name.to_s]
    return Result.new(status: :error, message: "そのアイテムはまだ使用できません。") unless status

    item = player.items.find_by(name: item_name)
    return Result.new(status: :error, message: "#{item_name}を持っていません。") unless item&.quantity.to_i.positive?
    return Result.new(status: :error, message: "その状態異常にはかかっていません。") unless StatusEffectService.active?(player, status)

    item.quantity -= 1
    StatusEffectService.cure!(player, status)

    ActiveRecord::Base.transaction do
      item.quantity.to_i <= 0 ? item.destroy! : item.save!
      player.save!
    end

    Result.new(status: :ok, message: "#{item_name}を使った。#{StatusEffectService::LABELS[status]}が治った。")
  end

  def self.eat_item!(player, item)
    return Result.new(status: :error, message: "そのアイテムは所持していません。") unless item&.quantity.to_i.positive?
    return Result.new(status: :error, message: "それは食べられません。") unless item.food?
    return Result.new(status: :error, message: "それは食べられそうにありません。") unless item.edible_by?(player)

    satiety_restore = item.effective_satiety_restore
    if player.satiety.to_d + satiety_restore > player.max_satiety
      return Result.new(status: :error, message: "これ以上は食べられそうにない。")
    end

    effect_data = item.effective_eat_effect_data
    hp_restore = effect_data["hp"].to_i
    status_effects = effect_data["statuses"].is_a?(Hash) ? effect_data["statuses"] : {}

    item.quantity -= 1
    player.hp = [player.hp.to_i + hp_restore, player.effective_max_hp].min if hp_restore.positive?
    player.increase_satiety!(satiety_restore)
    status_effects.each { |key, value| player.apply_status_effect!(key, value) }

    ActiveRecord::Base.transaction do
      item.quantity.to_i <= 0 ? item.destroy! : item.save!
      player.save!
    end

    messages = ["#{item.name}を食べた。"]
    messages << "HPが#{hp_restore}回復した。" if hp_restore.positive?
    status_effects.each_key do |key|
      messages << "#{Player::STATUS_LABELS.fetch(key.to_s, key.to_s)}状態になった。"
    end

    Result.new(status: :ok, message: messages.join, item: item)
  end

  def self.normalized_quantity(quantity)
    [quantity.to_i, 1].max
  end
end
