class RestaurantService
  Result = Struct.new(:status, :message, :menu_item, keyword_init: true)

  def self.eat_menu!(player, menu_name)
    menu_item = RestaurantCatalog.menu_item(player.location, menu_name)
    return Result.new(status: :error, message: "この店にはその料理がありません。") unless menu_item

    if menu_item.special?
      ingredient = RestaurantCatalog.ingredient_for(player, menu_item)
      if ingredient&.quantity.to_i < menu_item.required_item_quantity.to_i
        return Result.new(status: :error, message: "#{menu_item.menu_name}には#{menu_item.required_item_name}が#{menu_item.required_item_quantity}個必要です。")
      end
    end

    return Result.new(status: :error, message: "コルが足りません。#{menu_item.menu_name}は#{menu_item.price}コルです。") if player.col.to_i < menu_item.price
    return Result.new(status: :error, message: "これ以上は食べられそうにない。") if player.satiety.to_d >= player.max_satiety.to_d

    ActiveRecord::Base.transaction do
      ingredient = RestaurantCatalog.ingredient_for(player, menu_item)
      if ingredient
        ingredient.quantity = ingredient.quantity.to_i - menu_item.required_item_quantity.to_i
        ingredient.quantity.to_i <= 0 ? ingredient.destroy! : ingredient.save!
      end

      player.col = player.col.to_i - menu_item.price
      player.advance_time!(menu_item.preparation_minutes)
      player.increase_satiety!(menu_item.satiety_restore)
      BuffEffectService.apply_time_buff!(player, buff_key(menu_item), menu_item.buff_effects, duration_minutes: menu_item.duration_minutes)
      player.save!
    end

    messages = ["#{menu_item.menu_name}を食べた。"]
    messages << "#{menu_item.duration_minutes}分間、料理の効果を受ける。" if menu_item.buff_effects.present?
    messages << "#{menu_item.price}コル支払った。"
    messages << "#{menu_item.preparation_minutes}分経過した。"

    Result.new(status: :ok, message: messages.join, menu_item: menu_item)
  end

  def self.buff_key(menu_item)
    "restaurant:#{menu_item.location}:#{menu_item.menu_name}"
  end
end
