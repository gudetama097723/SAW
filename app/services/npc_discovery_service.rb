class NpcDiscoveryService
  Result = Struct.new(:status, :message, :npc, :discovery, keyword_init: true) do
    def discovered?
      status == :discovered
    end
  end

  def self.discover_during_stroll!(player)
    return none unless player&.location

    candidates = Npc.active
      .where(location: player.location, placement_type: %w[town facility])
      .ordered

    discover_from_candidates!(player, candidates)
  end

  def self.discover_during_explore!(player, field_area)
    return none unless player && field_area

    candidates = Npc.active
      .where(field_area: field_area, placement_type: "field_area")
      .ordered

    discover_from_candidates!(player, candidates)
  end

  def self.discover_from_candidates!(player, candidates)
    candidates.each do |npc|
      next unless discoverable?(player, npc)
      next unless roll_discovery?(npc)

      discovery = player.npc_discoveries.find_or_initialize_by(npc: npc)
      discovery.mark_discovered!

      return Result.new(
        status: :discovered,
        message: discovery_message(npc),
        npc: npc,
        discovery: discovery
      )
    end

    none
  end

  def self.discoverable?(player, npc)
    return false unless npc.active?

    discovery = player.npc_discoveries.find_by(npc: npc)
    return false if discovery&.currently_available?
    return false if discovery && !npc.repeat_discovery_required?

    discovery_conditions_met?(player, npc.discovery_conditions)
  end

  def self.discovery_conditions_met?(player, conditions)
    return true if conditions.blank?

    level_met?(player, conditions["level"]) &&
      skills_met?(player, conditions["skills"]) &&
      items_met?(player, conditions["items"])
  end

  def self.level_met?(player, condition)
    return true if condition.blank?

    required_level =
      if condition.is_a?(Hash)
        condition["min"] || condition[:min]
      else
        condition
      end

    player.effective_level >= required_level.to_i
  end

  def self.skills_met?(player, condition)
    required_names = Array(condition).filter_map(&:presence)
    return true if required_names.empty?

    player.skills.where(name: required_names).distinct.count == required_names.uniq.size
  end

  def self.items_met?(player, condition)
    required_items = Array(condition)
    return true if required_items.empty?

    required_items.all? do |entry|
      name = entry.is_a?(Hash) ? entry["name"] || entry[:name] : entry
      quantity = entry.is_a?(Hash) ? entry["quantity"] || entry[:quantity] || 1 : 1
      next false if name.blank?

      player.items.where(name: name).sum(:quantity).to_i >= quantity.to_i
    end
  end

  def self.roll_discovery?(npc)
    rand(100) < npc.effective_discovery_rate
  end

  def self.discovery_message(npc)
    if npc.repeat_discovery_required?
      "#{npc.name}を見かけた。今なら話しかけられそうだ。"
    else
      "#{npc.name}を発見した。以降、話しかけられるようになった。"
    end
  end

  def self.none
    Result.new(status: :none)
  end
end
