class BlacksmithService
  Context = Struct.new(:player, :npc, :proficiency, :facility_default, keyword_init: true) do
    def player?
      npc.nil? && !facility?
    end

    def npc?
      npc.present?
    end

    def facility?
      facility_default == true
    end

    def name
      return player.name if player?
      return npc.name if npc?

      "鍛冶屋"
    end

    def fee_multiplier(action)
      return 0.0 if player?
      return 1.0 if facility?

      attribute = {
        craft: :craft_fee_multiplier,
        maintenance: :maintenance_fee_multiplier,
        enhance: :enhance_fee_multiplier
      }.fetch(action.to_sym)
      npc.public_send(attribute).to_f
    end
  end

  def self.proficiency_cap_for_floor(floor)
    normalized_floor = floor.to_i.clamp(1, 100)
    (100 + (normalized_floor - 1) * (700.0 / 49)).round
  end

  def self.current_for(player)
    return unless BlacksmithFacilityAccessService.available?(player)

    Npc.active
      .where(location: player.location, placement_type: "facility", facility_key: "blacksmith")
      .ordered
      .first
  end

  def self.blacksmith_skill_for(player)
    player&.skills&.find_by(name: "鍛冶")
  end

  def self.context_for(player, mode: "npc", blacksmith: nil)
    if mode.to_s == "player"
      skill = blacksmith_skill_for(player)
      return unless skill

      Context.new(player: player, proficiency: skill.proficiency.to_i.clamp(0, 1000))
    else
      npc = blacksmith || current_for(player)
      if npc
        return unless BlacksmithFacilityAccessService.npc_available?(player, npc)

        Context.new(player: player, npc: npc, proficiency: npc.blacksmith_proficiency_for(player))
      elsif BlacksmithFacilityAccessService.available?(player)
        Context.new(player: player, proficiency: proficiency_cap_for_floor(player.floor), facility_default: true)
      end
    end
  end

  def self.proficiency_for(player, blacksmith = current_for(player))
    context_for(player, blacksmith: blacksmith)&.proficiency.to_i
  end

  def self.success_bonus_for(player, blacksmith = current_for(player), context: nil)
    proficiency = context&.proficiency || proficiency_for(player, blacksmith)
    (proficiency.to_i / 20.0).floor
  end

  def self.can_produce?(player, required_proficiency, blacksmith = current_for(player), context: nil)
    (context&.proficiency || proficiency_for(player, blacksmith)).to_i >= required_proficiency.to_i
  end

  def self.skill_label(context)
    return "鍛冶スキル未取得" unless context
    return "鍛冶熟練度：#{context.proficiency} / 1000" if context.player?

    case context.proficiency
    when 0...250 then "駆け出しの鍛冶師"
    when 250...500 then "腕利きの鍛冶師"
    when 500...800 then "熟練の鍛冶師"
    else "名工"
    end
  end
end
