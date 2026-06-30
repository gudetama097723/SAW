class NpcAffinityService
  Result = Struct.new(:status, :message, :affinity, :gain, :stage, :rule, keyword_init: true) do
    def ok?
      status == :ok
    end
  end

  STAGES = [
    [(1..20), "顔見知り"],
    [(21..40), "知人"],
    [(41..60), "友人"],
    [(61..80), "信頼"],
    [(81..99), "親友"],
    [(100..100), "特別"]
  ].freeze

  DAILY_ACTION_COLUMNS = {
    "chat" => :last_chat_affinity_day,
    "gift" => :last_gift_affinity_day
  }.freeze

  def self.gain!(player, npc, action_type:, target_key: nil, fallback_gain: nil)
    relation = relation_for(player, npc)
    rule = rule_for(npc, action_type, target_key)
    gain = rule&.affinity_gain || fallback_gain.to_i

    return blocked(relation, "親密度は上がらなかった。") if gain <= 0
    return blocked(relation, "まだ親密度が足りない。") if rule && relation.affinity.to_i < rule.required_affinity.to_i
    return blocked(relation, "今日はもう十分に交流した。") if rule&.daily_limit? && daily_limited?(player, relation, action_type)
    return blocked(relation, "条件を満たしていない。") if rule && !conditions_met?(relation, rule)

    before = relation.affinity.to_i.clamp(1, 100)
    maximum = NpcAffinityCapService.current_cap(relation)
    after = [before + gain.to_i, maximum].min

    relation.affinity = after
    mark_daily_limit!(player, relation, action_type) if rule&.daily_limit?
    relation.save!

    actual_gain = after - before
    Result.new(
      status: actual_gain.positive? ? :ok : :none,
      message: actual_gain.positive? ? "親密度が#{actual_gain}上がった。（#{stage_for(after)}）" : "親密度はこれ以上上がらなかった。",
      affinity: after,
      gain: actual_gain,
      stage: stage_for(after),
      rule: rule
    )
  end

  def self.gift!(player, npc, item_name)
    relation = relation_for(player, npc)
    item = player.items.where(name: item_name).where("quantity > 0").first
    unless item
      return Result.new(status: :error, message: "#{item_name}を持っていません。", affinity: relation.affinity.to_i, gain: 0, stage: stage_for(relation.affinity))
    end

    result = gain!(player, npc, action_type: "gift", target_key: item_name)
    return result unless result.ok?

    item.quantity = item.quantity.to_i - 1
    item.quantity.to_i <= 0 ? item.destroy! : item.save!
    result.message = "#{item_name}を渡した。#{result.message}"
    result
  end

  def self.stage_for(affinity)
    value = affinity.to_i.clamp(1, 100)
    STAGES.find { |range, _label| range.include?(value) }&.last || "顔見知り"
  end

  def self.relation_for(player, npc)
    player.npc_discoveries.find_or_create_by!(npc: npc) do |relation|
      relation.affinity = 1
      relation.affinity_cap = NpcAffinityCapService.initial_cap_for(npc)
    end.tap do |relation|
      NpcAffinityCapService.ensure_initial_cap!(relation)
    end
  end

  def self.rule_for(npc, action_type, target_key)
    rules = npc.npc_affinity_rules.active.where(action_type: action_type.to_s)
    rules = rules.where(target_key: [target_key.presence, nil, ""])
    rules.ordered.to_a.find { |rule| rule.target_key.blank? || rule.target_key == target_key.to_s }
  end

  def self.daily_limited?(player, relation, action_type)
    column = DAILY_ACTION_COLUMNS[action_type.to_s]
    return false unless column

    relation.public_send(column).to_i == game_day_key(player)
  end

  def self.mark_daily_limit!(player, relation, action_type)
    column = DAILY_ACTION_COLUMNS[action_type.to_s]
    return unless column

    relation.public_send("#{column}=", game_day_key(player))
  end

  def self.game_day_key(player)
    (player.current_month.to_i * 100) + player.current_day.to_i
  end

  def self.conditions_met?(relation, rule)
    conditions = rule.conditions
    required_events = Array(conditions["required_events"]).filter_map(&:presence)
    return true if required_events.empty?

    flags = relation.event_flags
    required_events.all? { |key| flags[key].present? }
  end

  def self.blocked(relation, message)
    Result.new(status: :none, message: message, affinity: relation.affinity.to_i, gain: 0, stage: stage_for(relation.affinity))
  end
end

