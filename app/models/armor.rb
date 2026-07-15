class Armor < ApplicationRecord
  EQUIPPABLE_SLOTS = %w[head neck body hands legs feet shield].freeze
  SLOT_NAMES = {
    "head" => "頭",
    "neck" => "首",
    "body" => "胴",
    "hands" => "手",
    "legs" => "脚",
    "feet" => "靴",
    "shield" => "盾"
  }.freeze

  belongs_to :player, optional: true
  belongs_to :player_base, optional: true

  before_save :unequip_other_armor_in_slot, if: :being_equipped_by_player?

  validates :slot, inclusion: { in: EQUIPPABLE_SLOTS }

  def broken? = durability.to_i <= 0

  def durability_rate
    return 0.0 unless max_durability.to_i.positive?
    (durability.to_f / max_durability).clamp(0.0, 1.0)
  end

  def durability_condition_label
    return "破損" if broken?
    return "破損寸前" if durability_rate <= 0.10
    return "損傷" if durability_rate <= 0.25
    return "消耗" if durability_rate <= 0.50
    "良好"
  end

  def durability_defense_multiplier
    return 0.10 if broken?
    return 0.50 if durability_rate <= 0.10
    return 0.70 if durability_rate <= 0.25
    return 0.85 if durability_rate <= 0.50
    1.0
  end

  def effective_defense = (defense.to_i * durability_defense_multiplier).ceil

  def apply_durability_loss!(amount = 1)
    update!(durability: [durability.to_i - amount.to_i, 0].max)
  end

  def repair_cost
    missing = [max_durability.to_i - durability.to_i, 0].max
    return 0 if missing.zero?
    full_cost = [defense.to_i * 15 + max_durability.to_i / 10 + weight.to_i * 5, 30].max
    [(full_cost * missing.to_f / [max_durability.to_i, 1].max).ceil, 1].max
  end

  def stored?
    player_base_id.present?
  end

  def slot_name
    self.class.slot_name(slot)
  end

  def self.slot_name(slot)
    SLOT_NAMES.fetch(slot, slot)
  end

  def protected_item?
    equipped? || favorite? || protected_from_death_penalty? || unique_item? || !discardable?
  end

  def sellable_by_player?
    !equipped? && !favorite? && discardable? && !protected_from_death_penalty?
  end

  def sell_price
    base = defense.to_i * 8 + max_durability.to_i / 10
    [(base * durability_rate / 2.0).floor, 1].max
  end

  def discardable_by_player?
    !equipped? && !favorite? && discardable? && !unique_item?
  end

  def status_resistance
    JSON.parse(status_resistance_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def status_resistance_bonus(status)
    status_resistance[status.to_s].to_i
  end

  private

  def being_equipped_by_player?
    player_id.present? && equipped? && (new_record? || will_save_change_to_equipped?)
  end

  def unequip_other_armor_in_slot
    player.armors.where(slot: slot, equipped: true).where.not(id: id).update_all(equipped: false)
  end
end

