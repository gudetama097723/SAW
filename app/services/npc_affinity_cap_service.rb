class NpcAffinityCapService
  Result = Struct.new(:status, :message, :cap, :rule, keyword_init: true) do
    def ok?
      status == :ok
    end
  end

  def self.ensure_initial_cap!(relation)
    return relation if relation.affinity_cap.to_i.positive?

    relation.affinity_cap = initial_cap_for(relation.npc)
    relation.save!
    relation
  end

  def self.initial_cap_for(npc)
    npc.initial_affinity_cap.to_i.clamp(1, 100)
  end

  def self.current_cap(relation)
    ensure_initial_cap!(relation)
    relation.affinity_cap.to_i.clamp(1, 100)
  end

  def self.unlock!(player, npc, unlock_type:, unlock_key:)
    relation = NpcAffinityService.relation_for(player, npc)
    ensure_initial_cap!(relation)

    rules = npc.npc_affinity_cap_rules.active
      .where(unlock_type: unlock_type.to_s, unlock_key: unlock_key.to_s)
      .ordered

    unlocked = []
    rules.each do |rule|
      next if rule.cap_value.to_i <= relation.affinity_cap.to_i
      next if relation.affinity.to_i < rule.required_affinity.to_i
      next if cap_flags(relation)[rule_key(rule)].present?
      next unless conditions_met?(relation, rule)

      flags = cap_flags(relation)
      flags[rule_key(rule)] = true
      relation.affinity_cap = rule.cap_value.to_i.clamp(1, 100)
      relation.affinity_cap_flags = flags.to_json
      relation.save!
      unlocked << rule
    end

    if unlocked.any?
      Result.new(status: :ok, message: "親密度上限が#{relation.affinity_cap}まで解放された。", cap: relation.affinity_cap, rule: unlocked.last)
    else
      Result.new(status: :none, message: "", cap: relation.affinity_cap)
    end
  end

  def self.cap_flags(relation)
    JSON.parse(relation.affinity_cap_flags.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def self.rule_key(rule)
    "#{rule.unlock_type}:#{rule.unlock_key}:#{rule.cap_value}"
  end

  def self.conditions_met?(relation, rule)
    conditions = rule.conditions
    required_events = Array(conditions["required_events"]).filter_map(&:presence)
    return true if required_events.empty?

    event_flags = relation.event_flags
    required_events.all? { |key| event_flags[key].present? }
  end
end
