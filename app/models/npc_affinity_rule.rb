class NpcAffinityRule < ApplicationRecord
  ACTION_TYPES = %w[first_talk chat info gift quest_clear event_clear].freeze

  belongs_to :npc

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }

  validates :action_type, inclusion: { in: ACTION_TYPES }
  validates :affinity_gain, numericality: { only_integer: true }
  validates :required_affinity, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  def conditions
    JSON.parse(conditions_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def allow_affinity_100?
    conditions["allow_affinity_100"] == true || conditions["allow_affinity_100"].to_s.downcase == "true"
  end
end
