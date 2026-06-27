class NpcDialogue < ApplicationRecord
  belongs_to :npc

  DIALOGUE_TYPES = %w[intro gossip info].freeze

  validates :dialogue_type, inclusion: { in: DIALOGUE_TYPES }
  validates :sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :text, presence: true

  scope :active, -> { where(active: true) }
  scope :intro, -> { where(dialogue_type: "intro").order(:sequence) }
  scope :gossip, -> { where(dialogue_type: "gossip") }
  scope :info, -> { where(dialogue_type: "info").order(:sequence) }
end
