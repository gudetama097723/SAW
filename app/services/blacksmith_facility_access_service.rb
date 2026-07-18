class BlacksmithFacilityAccessService
  MESSAGES = {
    craft: "武器を生産するには鍛冶設備が必要だ。",
    enhance: "武器を強化するには鍛冶設備が必要だ。",
    evolve: "武器を進化させるには鍛冶設備が必要だ。",
    npc_maintenance: "NPCへ整備を依頼するには鍛冶設備が必要だ。",
    facility: "ここには武器を鍛造できる設備がない。"
  }.freeze

  def self.available?(player)
    player.present? &&
      player.field_route.blank? &&
      player.location&.has_blacksmith_facility?
  end

  def self.npc_available?(player, npc)
    available?(player) &&
      npc&.active? &&
      npc.blacksmith? &&
      npc.location_id == player.location_id
  end

  def self.executor_available?(player, context)
    return false unless context
    return context.player == player if context.player?
    return context.player == player && available?(player) if context.facility?

    context.player == player && npc_available?(player, context.npc)
  end

  def self.message_for(action)
    MESSAGES.fetch(action.to_sym, MESSAGES[:facility])
  end
end
