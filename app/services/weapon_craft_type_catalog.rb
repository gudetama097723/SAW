class WeaponCraftTypeCatalog
  Template = Struct.new(
    :weapon_type, :attack_multiplier, :durability_multiplier, :weight_multiplier,
    :enhance_multiplier, :ore_quantity, :monster_quantity, :support_quantity,
    :attack_attributes, :name_suffix,
    keyword_init: true
  )

  def self.all
    @all ||= begin
      rows = []
      SimpleCsv.foreach(Rails.root.join("db", "seeds", "weapon_craft_types.csv")) { |row| rows << row }
      rows.map do |row|
        Template.new(
          weapon_type: row["weapon_type"], attack_multiplier: row["attack_multiplier"].to_f,
          durability_multiplier: row["durability_multiplier"].to_f, weight_multiplier: row["weight_multiplier"].to_f,
          enhance_multiplier: row["enhance_multiplier"].to_f, ore_quantity: row["ore_quantity"].to_i,
          monster_quantity: row["monster_quantity"].to_i, support_quantity: row["support_quantity"].to_i,
          attack_attributes: row["attack_attributes"], name_suffix: row["name_suffix"]
        )
      end
    end
  end

  def self.find(weapon_type)
    all.find { |template| template.weapon_type == weapon_type.to_s }
  end

  def self.reset!
    @all = nil
  end
end
