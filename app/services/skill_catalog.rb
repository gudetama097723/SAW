class SkillCatalog
  SkillDefinition = Struct.new(
    :key,
    :name,
    :skill_set,
    :required_proficiency,
    :damage_multiplier,
    :durability_cost,
    :skill_gain,
    :hits,
    :area,
    :target_type,
    :summary,
    :description,
    keyword_init: true
  ) do
    def area?
      area
    end

    def target_label
      area? ? "全体攻撃" : "単体攻撃"
    end

    def unlocked?(proficiency)
      proficiency.to_i >= required_proficiency.to_i
    end
  end

  def self.sword_skills
    all.select { |skill| skill.skill_set == "片手剣" }
  end

  def self.find(key)
    all.find { |skill| skill.key == key.to_s } || all.find { |skill| skill.key == "vertical" }
  end

  def self.all
    @all ||= load_definitions
  end

  def self.reload!
    @all = nil
  end

  def self.load_definitions
    path = Rails.root.join("db", "seeds", "sword_skills.csv")
    return fallback_definitions unless File.exist?(path)

    rows = []
    SimpleCsv.foreach(path) do |row|
      rows << SkillDefinition.new(
        key: row["key"],
        name: row["name"],
        skill_set: row["skill_set"],
        required_proficiency: row["required_proficiency"].to_i,
        damage_multiplier: row["damage_multiplier"].to_i,
        durability_cost: row["durability_cost"].to_i,
        skill_gain: row["skill_gain"].to_i,
        hits: row["hits"].to_i,
        area: row["area"].to_s == "true",
        target_type: row["target_type"],
        summary: row["summary"],
        description: row["description"]
      )
    end
    rows
  end

  def self.fallback_definitions
    [
      SkillDefinition.new(key: "vertical", name: "バーチカル", skill_set: "片手剣", required_proficiency: 0, damage_multiplier: 150, durability_cost: 2, skill_gain: 3, hits: 1, area: false, target_type: "single", summary: "倍率150% / 単体攻撃", description: "単発の縦斬り。通常攻撃より高威力。使用後に硬直が発生します。")
    ]
  end
end
