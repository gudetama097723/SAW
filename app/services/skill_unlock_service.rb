class SkillUnlockService
  Candidate = Struct.new(:name, :skill_category, :weapon_skill, keyword_init: true)

  DEFINITIONS = [
    Candidate.new(name: "生存本能", skill_category: "passive", weapon_skill: false),
    Candidate.new(name: "昼寝", skill_category: "rest", weapon_skill: false)
  ].freeze

  def self.available_for(player)
    DEFINITIONS.reject { |definition| player.skills.exists?(name: definition.name) }.select do |definition|
      case definition.name
      when "生存本能"
        player.skill_counter("severe_hunt_count") >= 1000
      when "昼寝"
        player.skill_counter("field_sleep_count") >= 100
      else
        false
      end
    end
  end
end
