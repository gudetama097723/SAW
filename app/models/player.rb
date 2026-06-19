class Player < ApplicationRecord
  HP_GROWTH_POINTS = [
    [1, 100],
    [10, 1783],
    [20, 4653],
    [50, 9263],
    [78, 14500]
  ].freeze

  SKILL_SLOT_LEVELS = [
    [1, 2],
    [5, 3],
    [10, 4],
    [20, 5],
    [30, 6],
    [40, 7],
    [50, 8],
    [60, 9],
    [70, 10],
    [85, 11],
    [100, 12]
  ].freeze

  has_many :skills, dependent: :destroy
  has_many :items, dependent: :destroy
  has_many :battles, dependent: :destroy
  has_many :rests, dependent: :destroy
  has_many :weapons, dependent: :destroy
  has_many :armors, dependent: :destroy
  has_many :player_route_progresses, dependent: :destroy
  has_many :player_town_discoveries, dependent: :destroy
  belongs_to :user, optional: true
  belongs_to :location, optional: true
  belongs_to :field_route, class_name: "Route", optional: true
  has_many :player_field_area_progresses, dependent: :destroy
  has_many :field_areas, through: :player_field_area_progresses
  has_many :player_treasure_chests, dependent: :destroy
  has_many :player_boss_kills, dependent: :destroy
  
  def equipped_weapons
    weapons.where(equipped: true)
  end

  def equipped_weapon
    equipped_weapons.first
  end

  def dual_wield?
    skills.exists?(name: "二刀流")
  end

  def equipped_armors
    armors.where(equipped: true)
  end

  def armor_for(slot)
    equipped_armors.find_by(slot: slot)
  end

  def town_discovery_for(target_location = location)
    return unless target_location

    player_town_discoveries.find_or_create_by!(location: target_location)
  end

  def effective_max_hp
    max_hp_before_armor_hp_bonus + armor_hp_bonus
  end

def status_value_data
  JSON.parse(status_values.presence || "{}")
rescue JSON::ParserError
  {}
end

def injury_state_data
  JSON.parse(injury_states.presence || "{}")
rescue JSON::ParserError
  {}
end

def skill_counter_data
  JSON.parse(skill_counters.presence || "{}")
rescue JSON::ParserError
  {}
end

def skill_counter(key)
  skill_counter_data[key.to_s].to_i
end

def increment_skill_counter!(key, amount = 1)
  data = skill_counter_data
  data[key.to_s] = data[key.to_s].to_i + amount.to_i
  update!(skill_counters: data.to_json)
end

def injury_severity
  rate = hp.to_i.to_f / [effective_max_hp, 1].max
  return "severe" if rate < 0.30
  return "minor" if rate < 0.70

  "none"
end

def injured?
  injury_severity != "none"
end

  def effective_strength
    strength.to_i + weapon_strength_bonus + armor_strength_bonus
  end

  def effective_agility
    base_agility = agility.to_i + weapon_agility_bonus + armor_agility_bonus
    [base_agility - equipment_weight_penalty, 1].max
  end

  def weapon_hp_bonus
    equipped_weapons.sum(:hp_bonus).to_i
  end

  def weapon_strength_bonus
    equipped_weapons.sum(:strength_bonus).to_i
  end

  def weapon_agility_bonus
    equipped_weapons.sum(:agility_bonus).to_i
  end

  def max_hp_before_armor_hp_bonus
    max_hp.to_i + weapon_hp_bonus + strength_hp_bonus
  end

  def strength_hp_bonus
    base_hp = max_hp.to_i
    cap = (base_hp / 3.0).round
    [(base_hp * hp_bonus_strength / 300.0).round, cap].min
  end

  def hp_bonus_strength
    strength.to_i
  end

  def armor_hp_bonus_percent
    equipped_armors.sum(:hp_bonus).to_i
  end

  def armor_hp_bonus
    (max_hp_before_armor_hp_bonus * armor_hp_bonus_percent / 100.0).round
  end

  def armor_strength_bonus
    equipped_armors.sum(:strength_bonus).to_i
  end

  def armor_agility_bonus
    equipped_armors.sum(:agility_bonus).to_i
  end

  def equipment_weight
    equipped_armors.sum(:weight).to_i
  end

  def equipment_weight_penalty
    [equipment_weight - effective_strength, 0].max
  end

  def damage_cut
    equipped_armors.sum(:defense).to_i
  end

  def used_skill_slots
    skills.select(:name).distinct.count
  end

  def remaining_skill_slots
    [skill_slots.to_i - used_skill_slots, 0].max
  end

  def skill_slots
    self.class.base_skill_slots_for_level(effective_level) + skill_slot_bonus.to_i
  end

  def exp_to_next_level
    self.class.exp_to_next_level_for(effective_level)
  end

  def effective_level
    [level.to_i, 1].max
  end

  def self.exp_to_next_level_for(level)
    100 * [level.to_i, 1].max**2
  end

  def self.max_hp_for_level(level)
    target_level = [level.to_i, 1].max
    return HP_GROWTH_POINTS.first.last if target_level <= HP_GROWTH_POINTS.first.first

    HP_GROWTH_POINTS.each_cons(2) do |(from_level, from_hp), (to_level, to_hp)|
      next unless target_level <= to_level

      progress = (target_level - from_level).to_f / (to_level - from_level)
      eased = progress * progress * (3 - (2 * progress))
      return (from_hp + ((to_hp - from_hp) * eased)).round
    end

    last_level, last_hp = HP_GROWTH_POINTS.last
    prev_level, prev_hp = HP_GROWTH_POINTS[-2]
    per_level = (last_hp - prev_hp).to_f / (last_level - prev_level)
    (last_hp + ((target_level - last_level) * per_level)).round
  end

  def self.base_skill_slots_for_level(level)
    target_level = [level.to_i, 1].max
    SKILL_SLOT_LEVELS.select { |required_level, _slots| target_level >= required_level }.last&.last || 2
  end

  def gain_exp!(amount)
    self.exp = exp.to_i + amount.to_i

    while exp >= exp_to_next_level
      self.exp -= exp_to_next_level
      self.level = level.to_i + 1
      self.max_hp = self.class.max_hp_for_level(level)
      self.stat_points = stat_points.to_i + 3
    end

    save!
  end

  def current_field_area
    return nil unless field_route

    field_route.field_areas.ordered.find do |area|
      area.include_distance?(field_position)
    end
  end

  def progress_for_area(area)
    return nil unless area

    player_field_area_progresses.find_or_create_by!(field_area: area) do |progress|
      progress.mapping_progress = 0
    end
  end

  def field_route_mapping_progress
    return 0 unless field_route

    areas = field_route.field_areas.ordered.to_a
    return 0 if areas.empty?

    progresses = player_field_area_progresses.where(field_area: areas).index_by(&:field_area_id)

    total = areas.sum do |area|
      progresses[area.id]&.mapping_progress.to_i
    end

    total / areas.size
  end
end
