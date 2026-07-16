class WeaponMaintenanceService
  Result = Struct.new(:status, :message, :skill_exp_gained, keyword_init: true)
  KIT_NAME = "武器整備キット"
  KIT_MAX_DURABILITY = 30

  def self.call(player:, weapon:, blacksmith:)
    return error("鍛冶を行える実行者がいません。") unless blacksmith
    return error("この鍛冶実行者は利用できません。") unless blacksmith.player == player
    return error("その武器は所持していません。") unless weapon&.player_id == player.id
    if blacksmith.npc? && !BlacksmithFacilityAccessService.npc_available?(player, blacksmith.npc)
      return error(BlacksmithFacilityAccessService.message_for(:npc_maintenance))
    end
    return error("この武器は整備を必要としていません。") unless weapon.durability.to_i < weapon.effective_max_durability
    if blacksmith.proficiency < weapon.maintenance_level.to_i
      return error("この武器を整備するには鍛冶の技量が足りない。")
    end

    fee = blacksmith.player? ? 0 : (weapon.repair_cost * blacksmith.fee_multiplier(:maintenance)).round
    kit = player.items.find_by(name: KIT_NAME) if blacksmith.player?
    return error("武器整備キットが必要です。") if blacksmith.player? && !kit&.quantity.to_i&.positive?
    return error("コルが足りません。整備には#{fee}コル必要です。") if player.col.to_i < fee

    missing = weapon.effective_max_durability - weapon.durability.to_i
    ratio = missing.to_f / [ weapon.effective_max_durability, 1 ].max
    kit_cost = kit_cost_for(blacksmith.proficiency)
    gained = 0
    insufficient_after_lock = false
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      still_missing_kit = blacksmith.player? && !player.items.find_by(name: KIT_NAME)&.quantity.to_i&.positive?
      if still_missing_kit || player.col.to_i < fee
        insufficient_after_lock = true
        raise ActiveRecord::Rollback
      end

      consume_kit!(kit, kit_cost) if blacksmith.player?
      player.col = player.col.to_i - fee
      player.advance_time!(20)
      weapon.update!(durability: weapon.effective_max_durability)
      player.save!
      gained = BlacksmithProficiencyService.award!(
        blacksmith, task_difficulty: weapon.maintenance_level, action: :maintenance,
        completion_ratio: ratio < 0.05 ? 0.0 : ratio
      )
    end
    return error(blacksmith.player? ? "武器整備キットが必要です。" : "コルが足りません。整備には#{fee}コル必要です。") if insufficient_after_lock

    cost_text = blacksmith.player? ? "整備キット耐久を#{kit_cost}消費" : "#{fee}コル支払った"
    Result.new(status: :ok, skill_exp_gained: gained, message: "#{weapon.display_name}を最大耐久まで整備した。#{cost_text}。")
  end

  def self.kit_cost_for(proficiency)
    case proficiency.to_i
    when 0...200 then 5
    when 200...400 then 4
    when 400...600 then 3
    when 600...800 then 2
    else 1
    end
  end

  def self.error(message)
    Result.new(status: :error, message: message)
  end
  private_class_method :error

  def self.consume_kit!(kit, amount)
    maximum = kit.max_durability.to_i.positive? ? kit.max_durability.to_i : KIT_MAX_DURABILITY
    remaining = kit.durability.to_i.positive? ? kit.durability.to_i : maximum
    remaining -= amount
    if remaining <= 0
      kit.quantity = kit.quantity.to_i - 1
      if kit.quantity.positive?
        kit.durability = maximum + remaining
        kit.max_durability = maximum
        kit.save!
      else
        kit.destroy!
      end
    else
      kit.update!(durability: remaining, max_durability: maximum)
    end
  end
  private_class_method :consume_kit!
end
