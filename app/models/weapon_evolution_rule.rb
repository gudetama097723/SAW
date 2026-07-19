class WeaponEvolutionRule < ApplicationRecord
  CONDITION_LABELS = {
    "enhancement_maxed" => ->(_condition) { "強化試行を上限まで成功させる" },
    "enhancement_level" => ->(condition) { "強化値+#{condition["min"].to_i}以上" },
    "critical_hits" => ->(condition) { "クリティカルヒット#{condition["min"].to_i}回以上" },
    "kills" => ->(condition) { "モンスター撃破#{condition["min"].to_i}体以上" }
  }.freeze

  def required_materials
    JSON.parse(required_materials_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def required_col
    required_materials["col"].to_i
  end

  def required_items
    required_materials["items"] || {}
  end

  def required_conditions
    JSON.parse(required_conditions_data.presence || "[]")
  rescue JSON::ParserError
    []
  end

  def conditions_met?(weapon)
    required_conditions.all? { |condition| condition_met?(weapon, condition) }
  end

  def condition_summaries(weapon)
    required_conditions.map do |condition|
      label = CONDITION_LABELS.fetch(condition["type"], ->(_condition) { "不明な条件" }).call(condition)
      "#{condition_met?(weapon, condition) ? "○" : "×"} #{label}"
    end
  end

  private

  def condition_met?(weapon, condition)
    case condition["type"]
    when "enhancement_maxed"
      weapon.fully_enhanced?
    when "enhancement_level"
      weapon.enhancement_level >= condition["min"].to_i
    when "critical_hits"
      weapon.critical_hit_count.to_i >= condition["min"].to_i
    when "kills"
      weapon.kill_count.to_i >= condition["min"].to_i
    else
      false
    end
  end
end
