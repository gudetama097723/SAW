class NpcAffinityCapRule < ApplicationRecord
  UNLOCK_TYPES = %w[quest_clear event_clear story_progress item_given flag].freeze

  belongs_to :npc

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }

  validates :cap_value, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }
  validates :unlock_type, inclusion: { in: UNLOCK_TYPES }
  validates :unlock_key, presence: true
  validates :required_affinity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def conditions
    JSON.parse(conditions_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
