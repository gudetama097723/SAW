class WeaponMaintenanceService
  Result = Struct.new(:status, :message, :skill_exp_gained, keyword_init: true)
  KIT_NAME = "武器整備キット"
  KIT_REPAIR_PERCENT = 0.5
  KIT_USE_COUNTER_KEY = "maintenance_kit_use_count"
  KIT_SKILL_UNLOCK_USES = 100

  def self.call(player:, weapon:, blacksmith:)
    return error("鍛冶を行える実行者がいません。") unless blacksmith
    return error("自分での整備は携帯用の武器整備キットから行ってください。") if blacksmith.player?
    return error("この鍛冶実行者は利用できません。") unless blacksmith.player == player
    return error("その武器は所持していません。") unless weapon&.player_id == player.id
    if blacksmith.npc? && !BlacksmithFacilityAccessService.npc_available?(player, blacksmith.npc)
      return error(BlacksmithFacilityAccessService.message_for(:npc_maintenance))
    end
    return error("この武器は整備を必要としていません。") unless weapon.durability.to_i < weapon.effective_max_durability
    if blacksmith.proficiency < weapon.maintenance_level.to_i
      return error("この武器を整備するには鍛冶の技量が足りない。")
    end

    fee = (weapon.repair_cost * blacksmith.fee_multiplier(:maintenance)).round
    return error("刻銭が足りません。整備には#{fee}刻銭必要です。") if player.col.to_i < fee

    missing = weapon.effective_max_durability - weapon.durability.to_i
    ratio = missing.to_f / [ weapon.effective_max_durability, 1 ].max
    gained = 0
    insufficient_after_lock = false
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      if player.col.to_i < fee
        insufficient_after_lock = true
        raise ActiveRecord::Rollback
      end

      player.col = player.col.to_i - fee
      player.advance_time!(20)
      weapon.update!(durability: weapon.effective_max_durability)
      player.save!
      gained = BlacksmithProficiencyService.award!(
        blacksmith, task_difficulty: weapon.maintenance_level, action: :maintenance,
        completion_ratio: ratio < 0.05 ? 0.0 : ratio
      )
    end
    return error("刻銭が足りません。整備には#{fee}刻銭必要です。") if insufficient_after_lock

    Result.new(status: :ok, skill_exp_gained: gained, message: "#{weapon.display_name}を最大耐久まで整備した。#{fee}刻銭支払った。")
  end

  # 武器整備キットは携帯用の消耗品として、鍛冶屋を介さずどこでも使える。
  # 鍛冶スキルの有無に関わらず使用可能で、これを累計100回使うと「鍛冶」
  # スキルの習得条件を満たす(SkillUnlockService参照)。
  def self.use_kit!(player:, weapon:)
    return error("その武器は所持していません。") unless weapon&.player_id == player.id
    return error("この武器は整備を必要としていません。") unless weapon.durability.to_i < weapon.effective_max_durability

    kit = player.items.find_by(name: KIT_NAME)
    return error("武器整備キットが必要です。") unless kit&.quantity.to_i&.positive?

    heal_amount = [ (weapon.effective_max_durability * KIT_REPAIR_PERCENT).ceil, 1 ].max
    insufficient_after_lock = false
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      kit.lock!
      still_missing_kit = !player.items.find_by(name: KIT_NAME)&.quantity.to_i&.positive?
      if still_missing_kit
        insufficient_after_lock = true
        raise ActiveRecord::Rollback
      end

      weapon.update!(durability: [ weapon.durability.to_i + heal_amount, weapon.effective_max_durability ].min)
      consume_kit!(kit)
      player.increment_skill_counter!(KIT_USE_COUNTER_KEY)
    end
    return error("武器整備キットが必要です。") if insufficient_after_lock

    Result.new(status: :ok, skill_exp_gained: 0, message: "#{weapon.display_name}の耐久を#{heal_amount}回復した。整備キットを1個消費。")
  end

  def self.error(message)
    Result.new(status: :error, message: message)
  end
  private_class_method :error

  def self.consume_kit!(kit)
    kit.quantity = kit.quantity.to_i - 1
    kit.quantity.positive? ? kit.save! : kit.destroy!
  end
  private_class_method :consume_kit!
end
