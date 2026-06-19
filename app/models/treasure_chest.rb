class TreasureChest < ApplicationRecord
  belongs_to :route
  belongs_to :field_area, optional: true
  has_many :player_treasure_chests, dependent: :destroy

  scope :fixed, -> { where(discovery_type: "fixed") }
  scope :mapping, -> { where(discovery_type: "mapping") }
  scope :available_at, ->(position) { where("position <= ?", position.to_i) }

  def reward
    JSON.parse(reward_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
