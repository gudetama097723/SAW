class WeaponProductionService
  Result = Struct.new(:status, :message, :weapon, keyword_init: true)
  Recipe = Struct.new(:location, :weapon_name, :required_col, :required_materials, keyword_init: true)

  def self.produce!(player, weapon_name)
    weapon_definition = ShopCatalog.blacksmith_production_weapon(player.location, weapon_name)
    return Result.new(status: :error, message: "この町では#{weapon_name}を生産できません。") unless weapon_definition

    recipe = recipe_for(player.location, weapon_name)
    return Result.new(status: :error, message: "#{weapon_name}の生産レシピがありません。") unless recipe
    return Result.new(status: :error, message: "コルが足りません。#{weapon_name}の生産には#{recipe.required_col}コル必要です。") if player.col.to_i < recipe.required_col

    missing = recipe.required_materials.find do |name, quantity|
      player.items.find_by(name: name)&.quantity.to_i < quantity.to_i
    end
    return Result.new(status: :error, message: "素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    weapon = nil
    ActiveRecord::Base.transaction do
      recipe.required_materials.each do |name, quantity|
        item = player.items.find_by!(name: name)
        item.quantity -= quantity.to_i
        item.quantity.to_i <= 0 ? item.destroy! : item.save!
      end

      player.col = player.col.to_i - recipe.required_col
      player.advance_time!(60)
      weapon = player.weapons.create!(
        name: weapon_definition.name,
        weapon_type: weapon_definition.weapon_type,
        rarity: weapon_definition.rarity,
        attack_power: weapon_definition.attack_power,
        durability: weapon_definition.durability,
        max_durability: weapon_definition.max_durability,
        hp_bonus: weapon_definition.hp_bonus,
        strength_bonus: weapon_definition.strength_bonus,
        agility_bonus: weapon_definition.agility_bonus,
        critical_rate: weapon_definition.critical_rate,
        part_break_power: weapon_definition.part_break_power,
        attack_attributes: weapon_definition.attack_attributes,
        weight: weapon_definition.weight,
        strength_ratio: weapon_definition.strength_ratio,
        agility_ratio: weapon_definition.agility_ratio,
        description: weapon_definition.description,
        equipped: false
      )
      player.save!
    end

    material_text = recipe.required_materials.map { |name, quantity| "#{name} ×#{quantity}" }.join("、")
    Result.new(status: :ok, message: "#{material_text}と#{recipe.required_col}コルで#{weapon.name}を生産した。", weapon: weapon)
  end

  def self.recipes_for(location)
    recipes.select { |recipe| recipe.location == location&.name }
  end

  def self.recipe_for(location, weapon_name)
    recipes_for(location).find { |recipe| recipe.weapon_name == weapon_name }
  end

  def self.recipes
    @recipes ||= load_recipes
  end

  def self.load_recipes
    path = Rails.root.join("db", "seeds", "blacksmith_weapon_production_recipes.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      Recipe.new(
        location: row["location"],
        weapon_name: row["weapon_name"],
        required_col: row["required_col"].to_i,
        required_materials: parse_materials(row["required_materials_data"])
      )
    end
  end

  def self.parse_materials(data)
    JSON.parse(data.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
