class WeaponEnhancementCatalog
  Step = Struct.new(:level, :base_col, :material_rank, :base_quantity, :rare_quantity, keyword_init: true)

  def self.step_for(level)
    all.find { |step| step.level == level.to_i }
  end

  def self.all
    @all ||= load_steps
  end

  def self.reload!
    @all = nil
  end

  def self.load_steps
    path = Rails.root.join("db", "seeds", "weapon_enhancement_steps.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      Step.new(
        level: row["level"].to_i,
        base_col: row["base_col"].to_i,
        material_rank: row["material_rank"],
        base_quantity: row["base_quantity"].to_i,
        rare_quantity: row["rare_quantity"].to_i
      )
    end
  end
end
