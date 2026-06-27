class NpcQuest < ApplicationRecord
  belongs_to :npc
  has_many :player_quests, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }

  def start_conditions
    JSON.parse(start_conditions_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def completion_conditions
    JSON.parse(completion_conditions_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def reward
    JSON.parse(reward_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
