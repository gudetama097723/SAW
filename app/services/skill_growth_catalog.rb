class SkillGrowthCatalog
  Growth = Struct.new(:name, :growth_scale, :use_exp, :kill_exp, :sword_skill_kill_bonus, keyword_init: true)

  def self.find(name)
    all.find { |growth| growth.name == name.to_s } || default_growth(name)
  end

  def self.all
    @all ||= load_definitions
  end

  def self.reload!
    @all = nil
  end

  def self.load_definitions
    path = Rails.root.join("db", "seeds", "skill_growth.csv")
    return [] unless File.exist?(path)

    rows = []
    SimpleCsv.foreach(path) do |row|
      rows << Growth.new(
        name: row["name"],
        growth_scale: positive_int(row["growth_scale"], 5000),
        use_exp: positive_int(row["use_exp"], 20),
        kill_exp: positive_int(row["kill_exp"], 40),
        sword_skill_kill_bonus: positive_int(row["sword_skill_kill_bonus"], 60)
      )
    end
    rows
  end

  def self.default_growth(name)
    Growth.new(name: name.to_s, growth_scale: 5000, use_exp: 20, kill_exp: 40, sword_skill_kill_bonus: 60)
  end

  def self.positive_int(value, fallback)
    number = value.to_i
    number.positive? ? number : fallback
  end
end
