class Armor < ApplicationRecord
  EQUIPPABLE_SLOTS = %w[head neck body hands feet].freeze
  SLOT_NAMES = {
    "head" => "頭",
    "neck" => "首",
    "body" => "胴",
    "hands" => "手",
    "feet" => "足"
  }.freeze

  belongs_to :player

  validates :slot, inclusion: { in: EQUIPPABLE_SLOTS }

  def slot_name
    self.class.slot_name(slot)
  end

  def self.slot_name(slot)
    SLOT_NAMES.fetch(slot, slot)
  end
end
