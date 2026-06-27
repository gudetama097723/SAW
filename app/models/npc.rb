class Npc < ApplicationRecord
  PLACEMENT_TYPES = %w[town facility field_area dungeon].freeze

  belongs_to :location, optional: true
  belongs_to :field_area, optional: true
  has_many :npc_discoveries, dependent: :destroy
  has_many :discovering_players, through: :npc_discoveries, source: :player
  has_many :npc_quests, dependent: :destroy

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }
  scope :placed_in, ->(placement_type) { where(placement_type: placement_type) }

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :npc_type, presence: true
  validates :placement_type, inclusion: { in: PLACEMENT_TYPES }
  validates :discovery_rate, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :placement_target_is_consistent

  def metadata
    JSON.parse(metadata_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def discovery_conditions
    JSON.parse(discovery_conditions_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def effective_discovery_rate
    discovery_rate.to_i.clamp(0, 100)
  end

  private

  def placement_target_is_consistent
    case placement_type
    when "town"
      errors.add(:location, "must exist for town placement") if location.blank?
      errors.add(:field_area, "must be blank for town placement") if field_area.present?
    when "facility"
      errors.add(:location, "must exist for facility placement") if location.blank?
      errors.add(:facility_key, "must exist for facility placement") if facility_key.blank?
      errors.add(:field_area, "must be blank for facility placement") if field_area.present?
    when "field_area"
      errors.add(:field_area, "must exist for field area placement") if field_area.blank?
      errors.add(:location, "must be blank for field area placement") if location.present?
    when "dungeon"
      errors.add(:dungeon_key, "must exist for dungeon placement") if dungeon_key.blank?
    end
  end
end
