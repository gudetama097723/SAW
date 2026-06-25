class ShopCatalog
  ItemDefinition = Struct.new(:location, :item_name, :category, :price, keyword_init: true)
  WeaponDefinition = Struct.new(
    :location,
    :name,
    :weapon_type,
    :rarity,
    :price,
    :attack_power,
    :durability,
    :max_durability,
    :hp_bonus,
    :strength_bonus,
    :agility_bonus,
    :critical_rate,
    :part_break_power,
    :attack_attributes,
    :enhancement_level,
    :weight,
    :strength_ratio,
    :agility_ratio,
    :description,
    :production_only,
    keyword_init: true
  )

  def self.item_shop_items(location)
    item_definitions.select { |item| item.location == location&.name }
  end

  def self.item_shop_item(location, item_name)
    item_shop_items(location).find { |item| item.item_name == item_name }
  end

  def self.blacksmith_weapons(location)
    weapon_definitions.select { |weapon| weapon.location == location&.name && !weapon.production_only }
  end

  def self.blacksmith_weapon(location, weapon_name)
    blacksmith_weapons(location).find { |weapon| weapon.name == weapon_name }
  end

  def self.blacksmith_production_weapons(location)
    weapon_definitions.select { |weapon| weapon.location == location&.name }
  end

  def self.blacksmith_production_weapon(location, weapon_name)
    blacksmith_production_weapons(location).find { |weapon| weapon.name == weapon_name }
  end

  def self.item_definitions
    @item_definitions ||= load_item_definitions
  end

  def self.weapon_definitions
    @weapon_definitions ||= load_weapon_definitions
  end

  def self.load_item_definitions
    path = Rails.root.join("db", "seeds", "item_shop_items.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      ItemDefinition.new(
        location: row["location"],
        item_name: row["item_name"],
        category: row["category"],
        price: row["price"].to_i
      )
    end
  end

  def self.load_weapon_definitions
    path = Rails.root.join("db", "seeds", "blacksmith_weapons.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      WeaponDefinition.new(
        location: row["location"],
        name: row["name"],
        weapon_type: row["weapon_type"],
        rarity: row["rarity"],
        price: row["price"].to_i,
        attack_power: row["attack_power"].to_i,
        durability: row["durability"].to_i,
        max_durability: row["max_durability"].to_i,
        hp_bonus: row["hp_bonus"].to_i,
        strength_bonus: row["strength_bonus"].to_i,
        agility_bonus: row["agility_bonus"].to_i,
        critical_rate: row["critical_rate"].to_i,
        part_break_power: row["part_break_power"].presence&.to_i || 100,
        attack_attributes: row["attack_attributes"].presence || "斬撃",
        enhancement_level: row["enhancement_level"].presence&.to_i || 0,
        weight: row["weight"].presence&.to_d || 5.to_d,
        strength_ratio: row["strength_ratio"].presence&.to_i || 70,
        agility_ratio: row["agility_ratio"].presence&.to_i || 30,
        description: row["description"].presence || "",
        production_only: ActiveModel::Type::Boolean.new.cast(row["production_only"])
      )
    end
  end
end
