class NpcDiscovery < ApplicationRecord
  belongs_to :player
  belongs_to :npc

  validates :npc_id, uniqueness: { scope: :player_id }

  def talkable?
    currently_available?
  end

  def mark_discovered!(time: Time.current)
    self.discovered_count = discovered_count.to_i + 1
    self.first_discovered_at ||= time
    self.last_discovered_at = time
    self.currently_available = true
    save!
  end

  def mark_spoken!(time: Time.current)
    self.last_spoken_at = time
    self.currently_available = false if npc.repeat_discovery_required?
    save!
  end

  def become_acquainted!
    update!(acquainted: true, last_spoken_at: Time.current)
  end

  def increment_affinity!(amount = 1)
    new_val = (affinity.to_i + amount.to_i).clamp(0, 100)
    update!(affinity: new_val)
    new_val
  end
end
