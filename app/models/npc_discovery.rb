class NpcDiscovery < ApplicationRecord
  belongs_to :player
  belongs_to :npc

  validates :npc_id, uniqueness: { scope: :player_id }
  validates :affinity, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }
  validates :affinity_cap, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 100 }

  before_validation :normalize_affinity

  def talkable?
    currently_available?
  end

  def mark_discovered!(time: Time.current)
    self.discovered_count = discovered_count.to_i + 1
    self.first_discovered_at ||= time
    self.last_discovered_at = time
    self.currently_available = true
    self.affinity_cap = NpcAffinityCapService.initial_cap_for(npc) unless affinity_cap.to_i.positive?
    save!
  end

  def mark_spoken!(time: Time.current)
    self.last_spoken_at = time
    self.currently_available = false if npc.repeat_discovery_required?
    save!
  end

  def become_acquainted!
    self.acquainted = true
    mark_spoken!
  end

  def increment_affinity!(amount = 1)
    new_val = (affinity.to_i + amount.to_i).clamp(1, affinity_cap.to_i.clamp(1, 100))
    update!(affinity: new_val)
    new_val
  end

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

  private

  def normalize_affinity
    self.affinity_cap = affinity_cap.to_i.positive? ? affinity_cap.to_i.clamp(1, 100) : NpcAffinityCapService.initial_cap_for(npc)
    self.affinity = affinity.to_i.clamp(1, affinity_cap)
  end
end
