class NpcQuest < ApplicationRecord
  QUEST_TYPES = {
    "npc" => "NPC固有クエスト",
    "board" => "掲示板依頼",
    "guild" => "ギルド依頼",
    "delivery" => "納品依頼",
    "hunt" => "討伐依頼",
    "seasonal" => "季節イベント"
  }.freeze

  belongs_to :npc
  has_many :player_quests, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :quest_type, presence: true, inclusion: { in: QUEST_TYPES.keys }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:sort_order, :id) }
  scope :repeatable, -> { where(repeatable: true) }
  scope :one_time, -> { where(repeatable: false) }

  before_validation :normalize_quest_type

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

  def repeat_policy
    JSON.parse(repeat_policy_json.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def quest_type_label
    QUEST_TYPES.fetch(quest_type, QUEST_TYPES.fetch("npc"))
  end

  def display_kind_label
    repeatable? ? "簡易依頼" : "クエスト"
  end

  def repeatability_label
    repeatable? ? "再受注可能" : "一回限定"
  end

  def completed_label
    repeatable? ? "達成済み・再受注可能" : "達成済み"
  end

  private

  def normalize_quest_type
    self.quest_type = quest_type.presence || "npc"
  end
end
