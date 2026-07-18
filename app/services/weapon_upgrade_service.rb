class WeaponUpgradeService
  Result = Struct.new(:status, :message, keyword_init: true)
  Quote = Struct.new(
    :enhancement_type, :name, :target_level, :required_col, :required_materials,
    :material_rank, :success_rate, :blacksmith_bonus, :processing_level,
    keyword_init: true
  )
  EffectPreview = Struct.new(:label, :before_value, :after_value, :unit, :precision, keyword_init: true)

  MATERIALS_BY_TYPE = {
    "S" => { "low" => "硬い甲殻", "medium" => "厚い甲殻", "high" => "コボルドの短刃片", "rare" => "小さな魔石" },
    "Q" => { "low" => "薄羽蜂の羽", "medium" => "薄羽蜂の外殻", "high" => "群狼の爪", "rare" => "小さな魔石" },
    "A" => { "low" => "薄羽蜂の針", "medium" => "ホーンラビットの角", "high" => "白銀の角", "rare" => "小さな魔石" },
    "H" => { "low" => "蟹の脚殻", "medium" => "厚い甲殻", "high" => "野猪の牙", "rare" => "小さな魔石" },
    "D" => { "low" => "硬い甲殻", "medium" => "丈夫な野猪革", "high" => "群狼の毛皮", "rare" => "小さな魔石" }
  }.freeze
  MATERIAL_RANK_LABELS = { "low" => "低級", "medium" => "中級", "high" => "上級" }.freeze

  def self.upgrade!(player, weapon, enhancement_type, blacksmith_mode: "npc")
    type = normalize_type(enhancement_type)
    return Result.new(status: :error, message: "強化方向を選択してください。") unless type
    return Result.new(status: :error, message: "その武器は所持していません。") unless weapon&.player_id == player.id
    unless BlacksmithFacilityAccessService.available?(player)
      return Result.new(status: :error, message: BlacksmithFacilityAccessService.message_for(:enhance))
    end
    return Result.new(status: :error, message: enhancement_limit_message(weapon)) if weapon.max_enhancement?

    blacksmith = BlacksmithService.current_for(player)
    context = BlacksmithService.context_for(player, mode: blacksmith_mode, blacksmith: blacksmith)
    return Result.new(status: :error, message: "鍛冶を行える実行者がいません。") unless context

    quote = quote_for(weapon, type, player: player, blacksmith: blacksmith, context: context)
    return Result.new(status: :error, message: "この武器の次段階の強化データがありません。") unless quote
    if context.proficiency < quote.processing_level.to_i
      return Result.new(status: :error, message: "この素材を扱うには鍛冶の技量が足りない。（必要熟練度#{quote.processing_level}）")
    end
    return Result.new(status: :error, message: "コルが足りません。強化には#{quote.required_col}コル必要です。") if player.col.to_i < quote.required_col

    missing = quote.required_materials.find do |name, quantity|
      player.items.find_by(name: name)&.quantity.to_i < quantity.to_i
    end
    return Result.new(status: :error, message: "素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    succeeded = false
    abort_reason = nil
    previous_level = weapon.enhancement_level
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      still_missing = quote.required_materials.find do |name, quantity|
        player.items.find_by(name: name)&.quantity.to_i < quantity.to_i
      end
      if weapon.max_enhancement?
        abort_reason = :max_enhancement
      elsif player.col.to_i < quote.required_col
        abort_reason = :insufficient_col
      elsif still_missing
        abort_reason = :insufficient_materials
      end
      raise ActiveRecord::Rollback if abort_reason

      consume_materials!(player, quote.required_materials)
      player.col = player.col.to_i - quote.required_col
      weapon.enhance_attempts = weapon.enhance_attempts.to_i + 1
      succeeded = rand(100) < quote.success_rate
      apply_success!(weapon, type) if succeeded
      weapon.enhancement_level = weapon.enhancement_level
      player.save!
      weapon.save!
      BlacksmithProficiencyService.award!(
        context, task_difficulty: quote.processing_level + quote.target_level * 10, action: :enhance
      )
    end
    if abort_reason == :max_enhancement
      return Result.new(status: :error, message: enhancement_limit_message(weapon))
    elsif abort_reason == :insufficient_col
      return Result.new(status: :error, message: "コルが足りません。強化には#{quote.required_col}コル必要です。")
    elsif abort_reason == :insufficient_materials
      return Result.new(status: :error, message: "素材が足りません。もう一度お試しください。")
    end

    if succeeded
      Result.new(
        status: :ok,
        message: "――強化成功！ #{context.name}が#{weapon.name}の《#{quote.name}》を強化した。#{quote.name} +1（+#{previous_level} → +#{weapon.enhancement_level}）"
      )
    else
      Result.new(
        status: :ok,
        message: "――強化失敗。武器性能に変化はなかった。強化試行可能数を1回消費した。"
      )
    end
  end

  def self.quote_for(weapon, enhancement_type, player: nil, blacksmith: nil, context: nil)
    type = normalize_type(enhancement_type)
    return unless weapon && type

    target_level = weapon.enhancement_level + 1
    step = WeaponEnhancementCatalog.step_for(target_level)
    return unless step

    difficulty = weapon.enhancement_difficulty.to_f
    context ||= BlacksmithService.context_for(player, blacksmith: blacksmith) if player
    blacksmith_bonus = BlacksmithService.success_bonus_for(player, blacksmith, context: context)
    required_materials = required_materials_for(type, step, difficulty)
    processing_level = required_materials.keys.filter_map { |name| BlacksmithMaterialCatalog.find(name)&.processing_level }.max.to_i
    base_fee = [ (step.base_col * difficulty).round, 1 ].max

    Quote.new(
      enhancement_type: type,
      name: Weapon::ENHANCEMENT_TYPES.fetch(type).fetch(:name),
      target_level: target_level,
      required_col: context&.player? ? 0 : (base_fee * (context&.fee_multiplier(:enhance) || 1.0)).round,
      required_materials: required_materials,
      material_rank: MATERIAL_RANK_LABELS.fetch(step.material_rank, step.material_rank),
      success_rate: success_rate_for(weapon, blacksmith_bonus: blacksmith_bonus),
      blacksmith_bonus: blacksmith_bonus,
      processing_level: processing_level
    )
  end

  def self.success_rate_for(weapon, blacksmith_bonus: 0, material_bonus: 0)
    difficulty_penalty = (weapon.enhancement_difficulty.to_f - 1.0) * 15
    rate = 95 - difficulty_penalty - weapon.enhance_attempts.to_i * 5 + blacksmith_bonus + material_bonus
    rate.round.clamp(5, 95)
  end

  def self.effect_previews_for(weapon, enhancement_type)
    type = normalize_type(enhancement_type)
    return [] unless weapon && type

    upgraded = weapon.dup
    attribute = Weapon::ENHANCEMENT_TYPES.fetch(type).fetch(:attribute)
    upgraded.public_send("#{attribute}=", upgraded.public_send(attribute).to_i + 1)

    case type
    when "S", "H"
      [
        effect_preview("強化後攻撃力", weapon.base_effective_attack_power, upgraded.base_effective_attack_power, precision: 2),
        effect_preview("部位破壊力", weapon.effective_part_break_power, upgraded.effective_part_break_power, unit: "pt", precision: 1)
      ]
    when "Q"
      [ 1, 2, 3, 4, 5 ].map do |hit_count|
        label = hit_count == 5 ? "ソードスキル倍率補正（5Hit以上）" : "ソードスキル倍率補正（#{hit_count}Hit）"
        effect_preview(
          label,
          weapon.sword_skill_damage_bonus_percent(hit_count),
          upgraded.sword_skill_damage_bonus_percent(hit_count),
          unit: "%",
          precision: 1
        )
      end
    when "A"
      [
        effect_preview("ソードスキル命中率補正", weapon.sword_skill_accuracy_bonus, upgraded.sword_skill_accuracy_bonus, unit: "pt"),
        effect_preview("ソードスキル会心率", weapon.sword_skill_critical_rate, upgraded.sword_skill_critical_rate, unit: "%")
      ]
    when "D"
      [
        effect_preview("最大耐久値", weapon.effective_max_durability, upgraded.effective_max_durability),
        effect_preview("耐久消費率", weapon.durability_cost_multiplier * 100, upgraded.durability_cost_multiplier * 100, unit: "%", precision: 1)
      ]
    end
  end

  def self.normalize_type(value)
    type = value.to_s.upcase
    type if Weapon::ENHANCEMENT_TYPES.key?(type)
  end

  def self.enhancement_limit_message(weapon)
    weapon.fully_enhanced? ? "この武器は完全強化されている。" : "この武器はこれ以上強化できない。"
  end

  def self.effect_preview(label, before_value, after_value, unit: "", precision: 0)
    EffectPreview.new(
      label: label,
      before_value: before_value,
      after_value: after_value,
      unit: unit,
      precision: precision
    )
  end
  private_class_method :effect_preview

  def self.required_materials_for(type, step, difficulty)
    materials = MATERIALS_BY_TYPE.fetch(type)
    required = { materials.fetch(step.material_rank) => [ (step.base_quantity * difficulty).ceil, 1 ].max }
    if step.rare_quantity.positive?
      required[materials.fetch("rare")] = [ (step.rare_quantity * difficulty).ceil, 1 ].max
    end
    required
  end
  private_class_method :required_materials_for

  def self.consume_materials!(player, materials)
    materials.each do |name, quantity|
      item = player.items.find_by!(name: name)
      item.quantity -= quantity.to_i
      item.quantity.to_i <= 0 ? item.destroy! : item.save!
    end
  end
  private_class_method :consume_materials!

  def self.apply_success!(weapon, type)
    attribute = Weapon::ENHANCEMENT_TYPES.fetch(type).fetch(:attribute)
    previous_max_durability = weapon.effective_max_durability
    weapon.public_send("#{attribute}=", weapon.public_send(attribute).to_i + 1)
    if type == "D"
      weapon.durability = weapon.durability.to_i + weapon.effective_max_durability - previous_max_durability
    end
  end
  private_class_method :apply_success!
end
