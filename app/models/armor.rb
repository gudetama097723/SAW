class Armor < ApplicationRecord
  EQUIPPABLE_SLOTS = %w[head neck body hands feet].freeze
  SLOT_NAMES = {
    "head" => "頭",
    "neck" => "首",
    "body" => "胴",
    "hands" => "手",
    "feet" => "足"
  }.freeze

  belongs_to :player, optional: true
  belongs_to :player_base, optional: true

  validates :slot, inclusion: { in: EQUIPPABLE_SLOTS }

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
end

