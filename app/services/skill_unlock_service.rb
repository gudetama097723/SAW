class SkillUnlockService
  Candidate = Struct.new(:name, :skill_category, :weapon_skill, keyword_init: true)

  DEFINITIONS = [
    Candidate.new(name: "生存本能", skill_category: "passive", weapon_skill: false),
    Candidate.new(name: "昼寝", skill_category: "rest", weapon_skill: false)
  ].freeze

  def self.available_for(player)
    candidates = DEFINITIONS + weapon_skill_candidates
    candidates.reject { |definition| player.skills.exists?(name: definition.name) }.select do |definition|
      case definition.name
      when "生存本能"
        player.skill_counter("severe_hunt_count") >= 1000
      when "昼寝"
        player.skill_counter("field_sleep_count") >= 100
      else
        definition.weapon_skill && player.skill_counter(weapon_attack_counter_key(definition.name)) >= 100
      end
    end
  end

  def self.weapon_attack_counter_key(skill_name)
    "normal_attack:#{skill_name}"
  end

  def self.weapon_skill_candidates
    SkillCatalog.all.map(&:skill_set).uniq.map do |skill_set|
      Candidate.new(name: skill_set, skill_category: "weapon", weapon_skill: true)
    end
  end
end
