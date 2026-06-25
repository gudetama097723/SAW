class BattleEnemy < ApplicationRecord
  belongs_to :battle
  belongs_to :mob

  scope :alive, -> { where("enemy_hp > 0").order(:position) }

  def alive?
    enemy_hp.to_i.positive?
  end

  def effective_level
    value = has_attribute?(:enemy_level) ? enemy_level : mob.level
    [value.to_i, 1].max
  end

  def effective_max_hp
    value = has_attribute?(:enemy_max_hp) ? enemy_max_hp : nil
    ((value.presence || scaled_value(mob.hp)) * StatusEffectService.max_hp_multiplier(self)).round
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

  def effective_atk
    scaled_value(mob.atk)
  end

  def effective_agility
    scaled_value(mob.agility)
  end

  def effective_durability
    scaled_value(mob.durability)
  end

  def effective_exp_reward
    scaled_value(mob.exp_reward)
  end

  def col_reward
    min_source = mob.has_attribute?(:col_min) ? mob.col_min : 1
    max_source = mob.has_attribute?(:col_max) ? mob.col_max : 3
    min = scaled_value(min_source)
    max = [scaled_value(max_source), min].max
    rand(min..max)
  end

  private

  def scaled_value(base)
    base_value = [base.to_i, 1].max
    multiplier = 1.0 + ((effective_level - 1) * 0.25)
    (base_value * multiplier).round
  end
end
