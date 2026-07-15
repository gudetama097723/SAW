class BattleEnemy < ApplicationRecord
  DISTANCES = {
    "near" => { label: "近距離", rank: 0 },
    "middle" => { label: "中距離", rank: 1 },
    "far" => { label: "遠距離", rank: 2 }
  }.freeze

  belongs_to :battle
  belongs_to :mob

  scope :alive, -> { where("enemy_hp > 0").order(:position) }

  def alive?
    enemy_hp.to_i.positive?
  end

  def effective_level
    return 1 unless level_based?

    value = has_attribute?(:enemy_level) ? enemy_level : mob.level
    [value.to_i, 1].max
  end

  def level_based?
    mob.level_based?
  end

  def display_name
    level_based? ? "#{mob.name} Lv#{effective_level}" : mob.name
  end

  def distance_key
    DISTANCES.key?(distance.to_s) ? distance.to_s : "near"
  end

  def distance_label
    DISTANCES.fetch(distance_key).fetch(:label)
  end

  def distance_rank
    DISTANCES.fetch(distance_key).fetch(:rank)
  end

  def increase_distance!
    next_distance = case distance_key
    when "near" then "middle"
    when "middle" then "far"
    else "far"
    end

    update!(distance: next_distance)
  end

  def decrease_distance!
    next_distance = case distance_key
    when "far" then "middle"
    when "middle" then "near"
    else "near"
    end

    update!(distance: next_distance)
  end

  def effective_max_hp
    value = has_attribute?(:enemy_max_hp) ? enemy_max_hp : nil
    ((value.presence || mob.hp_for_level(effective_level)) * StatusEffectService.max_hp_multiplier(self)).round
  end

  def status_value_data
    StatusEffectService.value_data(self)
  end

  def status_effect_data
    StatusEffectService.effect_data(self)
  end

  def condition_labels
    StatusEffectService.labels_for(self)
  end

  def status_accumulation_limit(status)
    mob.status_accumulation_limit(status)
  end

  def battle_effect_data
    BuffEffectService.battle_effects(self)
  end

  def effective_atk
    (mob.atk_for_level(effective_level) * BuffEffectService.attack_multiplier(self)).round
  end

  def effective_agility
    (mob.agility_for_level(effective_level) * BuffEffectService.agility_multiplier(self)).round
  end

  def effective_durability
    mob.durability_for_level(effective_level)
  end

  def effective_exp_reward
    [mob.exp_reward.to_i, 1].max
  end

  def col_reward
    min = mob.col_min_for_level(effective_level)
    max = [mob.col_max_for_level(effective_level), min].max
    rand(min..max)
  end
end
