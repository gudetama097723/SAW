class PlayerNpc < ApplicationRecord
  self.table_name = "npc_discoveries"

  belongs_to :player
  belongs_to :npc

  validates :npc_id, uniqueness: { scope: :player_id }
  validates :affinity, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }
  validates :affinity_cap, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }

  def affinity_stage
    NpcAffinityService.stage_for(affinity)
  end

  def cap_flags
    JSON.parse(affinity_cap_flags.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def event_flags
    JSON.parse(affinity_event_flags.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
