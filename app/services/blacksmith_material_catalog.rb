class BlacksmithMaterialCatalog
  Material = Struct.new(
    :name, :category, :processing_level, :craft_attack, :craft_durability, :craft_weight,
    :craft_enhance_limit, :craft_rank, :craft_tags, :attack_modifier,
    :durability_modifier, :weight_modifier, :break_modifier, :target_quality,
    :min_quality_bonus, :max_quality_bonus,
    keyword_init: true
  )

  def self.all
    @all ||= load_all
  end

  def self.for_category(category)
    all.select { |material| material.category == category.to_s }
  end

  def self.find(name, category: nil)
    all.find { |material| material.name == name.to_s && (!category || material.category == category.to_s) }
  end

  def self.reset!
    @all = nil
  end

  def self.load_all
    rows = []
    SimpleCsv.foreach(Rails.root.join("db", "seeds", "blacksmith_materials.csv")) { |row| rows << row }
    rows.map do |row|
      Material.new(
        name: row["name"], category: row["category"], processing_level: row["processing_level"].to_i,
        craft_attack: row["craft_attack"].to_i, craft_durability: row["craft_durability"].to_i,
        craft_weight: row["craft_weight"].to_f, craft_enhance_limit: row["craft_enhance_limit"].to_i,
        craft_rank: row["craft_rank"].to_i, craft_tags: row["craft_tags"].to_s.split("|").reject(&:blank?),
        attack_modifier: decimal_or_one(row["attack_modifier"]), durability_modifier: decimal_or_one(row["durability_modifier"]),
        weight_modifier: decimal_or_one(row["weight_modifier"]), break_modifier: row["break_modifier"].to_i,
        target_quality: row["target_quality"].presence, min_quality_bonus: row["min_quality_bonus"].to_f,
        max_quality_bonus: row["max_quality_bonus"].to_f
      )
    end
  end
  private_class_method :load_all

  def self.decimal_or_one(value)
    value.present? ? value.to_f : 1.0
  end
  private_class_method :decimal_or_one
end
