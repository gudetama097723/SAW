class ItemService
  POTION_PRICE = 50
  POTION_PRODUCTION_COST = 20
  POTION_HEAL = 100
  HERBS_PER_POTION = 10

  Result = Struct.new(:status, :message, :item, keyword_init: true)

  def self.add_item!(player, name, category, quantity = 1)
    item = player.items.find_or_create_by!(name: name, category: category) do |new_item|
      new_item.quantity = 0
    end
    item.quantity = item.quantity.to_i + quantity.to_i
    item
  end

  def self.buy_potion!(player)
    return Result.new(status: :error, message: "コルが足りません。ポーションは#{POTION_PRICE}コルです。") if player.col.to_i < POTION_PRICE

    player.col = player.col.to_i - POTION_PRICE
    player.current_time = (player.current_time.to_i + 5) % 1440
    potion = add_item!(player, "ポーション", "healing")

    ActiveRecord::Base.transaction do
      player.save!
      potion.save!
    end

    Result.new(status: :ok, message: "道具屋でポーションを1本購入した。#{POTION_PRICE}コル支払った。", item: potion)
  end

  def self.produce_potion!(player)
    herb = player.items.find_by(name: "薬草", category: "gathered") || player.items.find_by(name: "薬草")
    if (herb&.quantity || 0).to_i < HERBS_PER_POTION
      return Result.new(status: :error, message: "薬草が足りません。ポーションの生産には薬草#{HERBS_PER_POTION}個が必要です。")
    end

    if player.col.to_i < POTION_PRODUCTION_COST
      return Result.new(status: :error, message: "コルが足りません。ポーションの生産には#{POTION_PRODUCTION_COST}コル必要です。")
    end

    herb.quantity -= HERBS_PER_POTION
    player.col = player.col.to_i - POTION_PRODUCTION_COST
    player.current_time = (player.current_time.to_i + 15) % 1440
    potion = add_item!(player, "ポーション", "healing")

    ActiveRecord::Base.transaction do
      herb.quantity.to_i <= 0 ? herb.destroy! : herb.save!
      potion.save!
      player.save!
    end

    Result.new(status: :ok, message: "薬草#{HERBS_PER_POTION}個と#{POTION_PRODUCTION_COST}コルでポーションを1本生産した。", item: potion)
  end

  def self.sell_item!(player, item)
    return Result.new(status: :error, message: "売却できるアイテムがありません。") unless item&.quantity.to_i.positive?

    price = item.sell_price
    item.quantity -= 1
    player.col = player.col.to_i + price
    player.current_time = (player.current_time.to_i + 5) % 1440

    ActiveRecord::Base.transaction do
      item.quantity.to_i <= 0 ? item.destroy! : item.save!
      player.save!
    end

    Result.new(status: :ok, message: "#{item.name}を#{price}コルで売却した。")
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
end
