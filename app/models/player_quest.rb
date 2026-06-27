class PlayerQuest < ApplicationRecord
  belongs_to :player
  belongs_to :npc_quest

  STATUSES = %w[active completed].freeze

  validates :status, inclusion: { in: STATUSES }

  scope :active,    -> { where(status: "active") }
  scope :completed, -> { where(status: "completed") }

  def active?
    status == "active"
  end

  def completed?
    status == "completed"
  end
end
