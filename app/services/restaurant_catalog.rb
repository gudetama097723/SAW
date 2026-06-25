class RestaurantCatalog
  MenuItem = Struct.new(
    :location,
    :restaurant_name,
    :menu_name,
    :price,
    :satiety_restore,
    :duration_minutes,
    :preparation_minutes,
    :hp_bonus,
    :strength_bonus,
    :agility_bonus,
    :accuracy_bonus,
    :required_item_name,
    :required_item_category,
    :required_item_quantity,
    :description,
    keyword_init: true
  ) do
    def special?
      required_item_name.present?
    end

    def buff_effects
      {
        hp: hp_bonus,
        strength: strength_bonus,
        agility: agility_bonus,
        accuracy: accuracy_bonus
      }.select { |_key, value| value.to_i != 0 }
    end
  end

  def self.restaurant_name(location)
    menu_items(location).first&.restaurant_name || "飲食店"
  end

  def self.menu_items(location)
    definitions.select { |item| item.location == location&.name }
  end

  def self.available_menu_items(player)
    menu_items(player.location).select { |item| !item.special? || ingredient_for(player, item)&.quantity.to_i >= item.required_item_quantity.to_i }
  end

  def self.menu_item(location, menu_name)
    menu_items(location).find { |item| item.menu_name == menu_name }
  end

  def self.ingredient_for(player, menu_item)
    return nil unless menu_item&.special?

    scope = player.items.where(name: menu_item.required_item_name)
    menu_item.required_item_category.present? ? scope.find_by(category: menu_item.required_item_category) : scope.first
  end

  def self.definitions
    @definitions ||= load_definitions
  end

  def self.load_definitions
    path = Rails.root.join("db", "seeds", "restaurant_menus.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      MenuItem.new(
        location: row["location"],
        restaurant_name: row["restaurant_name"],
        menu_name: row["menu_name"],
        price: row["price"].to_i,
        satiety_restore: row["satiety_restore"].to_i,
        duration_minutes: row["duration_minutes"].to_i,
        preparation_minutes: row["preparation_minutes"].presence&.to_i || 20,
        hp_bonus: row["hp_bonus"].to_i,
        strength_bonus: row["strength_bonus"].to_i,
        agility_bonus: row["agility_bonus"].to_i,
        accuracy_bonus: row["accuracy_bonus"].to_i,
        required_item_name: row["required_item_name"].presence,
        required_item_category: row["required_item_category"].presence,
        required_item_quantity: row["required_item_quantity"].presence&.to_i || 0,
        description: row["description"].presence || ""
      )
    end
  end
end
