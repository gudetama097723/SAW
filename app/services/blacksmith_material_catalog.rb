class BlacksmithMaterialCatalog
  Material = Struct.new(
    :name, :category, :processing_level, :craft_attack, :craft_durability, :craft_weight,
    :craft_enhance_limit, :craft_rank, :craft_tags, :attack_modifier,
    :durability_modifier, :weight_modifier, :break_modifier, :target_quality,
    :min_quality_bonus, :max_quality_bonus, :enhancement_points, :enhancement_types,
    keyword_init: true
  ) do
    QUALITY_TARGET_LABELS = { "attack" => "攻撃品質", "durability" => "耐久品質", "weight" => "重量品質", "enhance" => "強化上限品質" }.freeze

    # 生産UIで素材選択時に表示する効果の短い説明文。既存CSV列から動的に生成する
    def effect_summary
      parts = [
        percent_text("攻撃", attack_modifier),
        percent_text("耐久", durability_modifier),
        percent_text("重量", weight_modifier),
        (break_modifier.to_i != 0 ? "部位破壊#{break_modifier.to_i >= 0 ? '+' : ''}#{break_modifier.to_i}pt" : nil),
        quality_bonus_text
      ].compact
      parts.presence&.join("／") || "特殊効果なし"
    end

    private

    def percent_text(label, modifier)
      return nil if modifier.to_f == 1.0

      percent = ((modifier.to_f - 1.0) * 100).round
      "#{label}#{percent >= 0 ? '+' : ''}#{percent}%"
    end

    def quality_bonus_text
      return nil if target_quality.blank?

      label = QUALITY_TARGET_LABELS.fetch(target_quality, target_quality)
      "#{label}+#{format('%.2f', min_quality_bonus)}〜#{format('%.2f', max_quality_bonus)}"
    end
  end

  def self.all
    @all ||= load_all
  end

  def self.for_category(category)
    all.select { |material| material.category == category.to_s }
  end

  def self.find(name, category: nil)
    all.find { |material| material.name == name.to_s && (!category || material.category == category.to_s) }
  end

  def self.for_enhancement(type, minimum_points: 1)
    all.select do |material|
      material.enhancement_points.to_i >= minimum_points.to_i && material.enhancement_types.include?(type.to_s.upcase)
    end
  end

  def self.reset!
    @all = nil
  end

  def self.load_all
    path = Rails.root.join("db", "seeds", "blacksmith_materials.csv")
    return [] unless File.exist?(path)

    rows = []
    SimpleCsv.foreach(path) { |row| rows << row }
    rows.map do |row|
      Material.new(
        name: row["name"], category: row["category"], processing_level: row["processing_level"].to_i,
        craft_attack: row["craft_attack"].to_i, craft_durability: row["craft_durability"].to_i,
        craft_weight: row["craft_weight"].to_f, craft_enhance_limit: row["craft_enhance_limit"].to_i,
        craft_rank: row["craft_rank"].to_i, craft_tags: row["craft_tags"].to_s.split("|").reject(&:blank?),
        attack_modifier: decimal_or_one(row["attack_modifier"]), durability_modifier: decimal_or_one(row["durability_modifier"]),
        weight_modifier: decimal_or_one(row["weight_modifier"]), break_modifier: row["break_modifier"].to_i,
        target_quality: row["target_quality"].presence, min_quality_bonus: row["min_quality_bonus"].to_f,
        max_quality_bonus: row["max_quality_bonus"].to_f,
        enhancement_points: row["enhancement_points"].to_i,
        enhancement_types: row["enhancement_types"].to_s.split("|").reject(&:blank?)
      )
    end
  end
  private_class_method :load_all

  def self.decimal_or_one(value)
    value.present? ? value.to_f : 1.0
  end
  private_class_method :decimal_or_one
end
