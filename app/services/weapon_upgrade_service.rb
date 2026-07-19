class WeaponUpgradeService
  Result = Struct.new(:status, :message, keyword_init: true)
  Quote = Struct.new(
    :enhancement_type, :name, :target_level, :required_col, :required_materials,
    :base_required_materials, :additional_materials, :material_rank,
    :base_success_rate, :success_rate, :blacksmith_bonus, :processing_level,
    :required_points, :base_guaranteed_points, :guaranteed_points,
    :guaranteed_point_reduction, :proficiency_reduction_rate,
    :invested_points, :point_shortage,
    keyword_init: true
  ) do
    def points_satisfied? = point_shortage.to_i.zero?
  end
  EffectPreview = Struct.new(:label, :before_value, :after_value, :unit, :precision, keyword_init: true)

  MATERIALS_BY_TYPE = {
    "S" => { "low" => "硬い甲殻", "medium" => "厚い甲殻", "high" => "コボルドの短刃片", "rare" => "小さな魔石" },
    "Q" => { "low" => "薄羽蜂の羽", "medium" => "薄羽蜂の外殻", "high" => "群狼の爪", "rare" => "小さな魔石" },
    "A" => { "low" => "薄羽蜂の針", "medium" => "ホーンラビットの角", "high" => "白銀の角", "rare" => "小さな魔石" },
    "H" => { "low" => "蟹の脚殻", "medium" => "厚い甲殻", "high" => "野猪の牙", "rare" => "小さな魔石" },
    "D" => { "low" => "硬い甲殻", "medium" => "丈夫な野猪革", "high" => "群狼の毛皮", "rare" => "小さな魔石" }
  }.freeze
  MATERIAL_RANK_LABELS = { "low" => "低級", "medium" => "中級", "high" => "上級" }.freeze
  DEFAULT_GUARANTEE_MULTIPLIER = 64.0
  FIRST_FLOOR_GUARANTEE_MULTIPLIER = 6.5

  def self.upgrade!(player, weapon, enhancement_type, blacksmith_mode: "npc", material_quantities: nil)
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

    quote = quote_for(
      weapon, type, player: player, blacksmith: blacksmith, context: context, material_quantities: material_quantities
    )
    return Result.new(status: :error, message: "この武器の次段階の強化データがありません。") unless quote
    unless quote.points_satisfied?
      return Result.new(status: :error, message: "強化ポイントが#{quote.point_shortage}pt不足しています。")
    end
    if context.proficiency < quote.processing_level.to_i
      return Result.new(status: :error, message: "この素材を扱うには鍛冶の技量が足りない。（必要熟練度#{quote.processing_level}）")
    end
    return Result.new(status: :error, message: "刻銭が足りません。強化には#{quote.required_col}刻銭必要です。") if player.col.to_i < quote.required_col

    missing = quote.required_materials.find do |name, quantity|
      player.items.where(name: name).sum(:quantity).to_i < quantity.to_i
    end
    return Result.new(status: :error, message: "素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    succeeded = false
    abort_reason = nil
    previous_level = weapon.enhancement_level
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      still_missing = quote.required_materials.find do |name, quantity|
        player.items.where(name: name).sum(:quantity).to_i < quantity.to_i
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
      return Result.new(status: :error, message: "刻銭が足りません。強化には#{quote.required_col}刻銭必要です。")
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

  def self.quote_for(weapon, enhancement_type, player: nil, blacksmith: nil, context: nil, material_quantities: nil)
    type = normalize_type(enhancement_type)
    return unless weapon && type

    target_level = weapon.enhancement_level + 1
    step = WeaponEnhancementCatalog.step_for(target_level)
    return unless step

    difficulty = weapon.enhancement_difficulty.to_f
    context ||= BlacksmithService.context_for(player, blacksmith: blacksmith) if player
    blacksmith_bonus = BlacksmithService.success_bonus_for(player, blacksmith, context: context)
    base_success_rate = success_rate_for(weapon, blacksmith_bonus: blacksmith_bonus)
    required_points = required_points_for(step, difficulty)
    guarantee_multiplier = player&.floor.to_i == 1 ? FIRST_FLOOR_GUARANTEE_MULTIPLIER : DEFAULT_GUARANTEE_MULTIPLIER
    base_guaranteed_points = (required_points * guarantee_multiplier).ceil
    guaranteed_points, proficiency_reduction_rate = guaranteed_points_for(
      required_points, context&.proficiency, base_guaranteed_points: base_guaranteed_points
    )
    base_required_materials = default_material_allocation(type, step, required_points)
    required_materials = material_quantities.nil? ? default_material_allocation(type, step, required_points) : normalize_material_quantities(material_quantities, type, step)
    additional_materials = material_quantities.nil? ? material_difference(required_materials, base_required_materials) : {}
    invested_points = material_points_for(required_materials)
    processing_level = required_materials.keys.filter_map { |name| BlacksmithMaterialCatalog.find(name)&.processing_level }.max.to_i
    base_fee = [ (step.base_col * difficulty).round, 1 ].max

    Quote.new(
      enhancement_type: type,
      name: Weapon::ENHANCEMENT_TYPES.fetch(type).fetch(:name),
      target_level: target_level,
      required_col: context&.player? ? 0 : (base_fee * (context&.fee_multiplier(:enhance) || 1.0)).round,
      required_materials: required_materials,
      base_required_materials: base_required_materials,
      additional_materials: additional_materials,
      material_rank: MATERIAL_RANK_LABELS.fetch(step.material_rank, step.material_rank),
      base_success_rate: base_success_rate,
      success_rate: success_rate_for_points(
        base_success_rate, required_points, invested_points, guaranteed_points: guaranteed_points
      ),
      blacksmith_bonus: blacksmith_bonus,
      processing_level: processing_level,
      required_points: required_points,
      base_guaranteed_points: base_guaranteed_points,
      guaranteed_points: guaranteed_points,
      guaranteed_point_reduction: base_guaranteed_points - guaranteed_points,
      proficiency_reduction_rate: proficiency_reduction_rate,
      invested_points: invested_points,
      point_shortage: [ required_points - invested_points, 0 ].max
    )
  end

  def self.material_options_for(player, enhancement_type, material_rank, proficiency:)
    minimum = { "low" => 1, "medium" => 3, "high" => 8 }.fetch(material_rank.to_s, 1)
    options = BlacksmithMaterialCatalog.for_enhancement(enhancement_type, minimum_points: minimum).filter_map do |material|
      owned = player&.items&.where(name: material.name)&.sum(:quantity).to_i
      [ material, owned ] if owned.positive? && material.processing_level.to_i <= proficiency.to_i
    end
    options.sort_by { |material, _owned| [ material.enhancement_points.to_i, material.name ] }
  end

  def self.success_rate_for(weapon, blacksmith_bonus: 0)
    difficulty_penalty = (weapon.enhancement_difficulty.to_f - 1.0) * 15
    rate = 95 - difficulty_penalty - weapon.enhance_attempts.to_i * 5 + blacksmith_bonus
    rate.round.clamp(5, 95)
  end

  def self.success_rate_for_points(base_success_rate, required_points, invested_points, guaranteed_points: required_points.to_i * 64)
    return base_success_rate.to_f if invested_points.to_i <= required_points.to_i
    return 100.0 if invested_points.to_i >= guaranteed_points.to_i

    multiplier = invested_points.to_f / required_points.to_f
    maximum_multiplier = guaranteed_points.to_f / required_points.to_f
    progress = Math.log2(multiplier) / Math.log2(maximum_multiplier)
    (base_success_rate + (100.0 - base_success_rate) * progress).round(1).clamp(base_success_rate.to_f, 100.0)
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
        label = hit_count == 5 ? "錬技倍率補正（5Hit以上）" : "錬技倍率補正（#{hit_count}Hit）"
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
        effect_preview("錬技命中率補正", weapon.sword_skill_accuracy_bonus, upgraded.sword_skill_accuracy_bonus, unit: "pt"),
        effect_preview("錬技会心率", weapon.sword_skill_critical_rate, upgraded.sword_skill_critical_rate, unit: "%")
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

  def self.required_points_for(step, difficulty)
    rank_points = { "low" => 1, "medium" => 3, "high" => 8 }.fetch(step.material_rank, 1)
    [ ((step.base_quantity * rank_points + step.rare_quantity * 25) * difficulty).ceil, 1 ].max
  end
  private_class_method :required_points_for

  def self.guaranteed_points_for(required_points, proficiency, base_guaranteed_points:)
    proficiency_steps = proficiency.to_i.clamp(0, 1000) / 10
    reduction_rate = proficiency_steps / 200.0
    guaranteed_points = [ (base_guaranteed_points * (1.0 - reduction_rate)).ceil, required_points.to_i ].max
    [ guaranteed_points, reduction_rate ]
  end
  private_class_method :guaranteed_points_for

  def self.default_material_allocation(type, step, required_points)
    name = MATERIALS_BY_TYPE.fetch(type).fetch(step.material_rank)
    points = BlacksmithMaterialCatalog.find(name)&.enhancement_points.to_i
    { name => (required_points.to_f / [ points, 1 ].max).ceil }
  end
  private_class_method :default_material_allocation

  def self.normalize_material_quantities(quantities, type, step)
    minimum = { "low" => 1, "medium" => 3, "high" => 8 }.fetch(step.material_rank, 1)
    allowed = BlacksmithMaterialCatalog.for_enhancement(type, minimum_points: minimum).index_by(&:name)
    quantities.to_h.each_with_object({}) do |(name, quantity), result|
      count = quantity.to_i
      result[name.to_s] = count if count.positive? && allowed.key?(name.to_s)
    end
  end
  private_class_method :normalize_material_quantities

  def self.material_points_for(materials)
    materials.sum { |name, quantity| BlacksmithMaterialCatalog.find(name)&.enhancement_points.to_i * quantity.to_i }
  end
  private_class_method :material_points_for

  def self.material_difference(total, base)
    total.each_with_object({}) do |(name, quantity), result|
      difference = quantity.to_i - base.fetch(name, 0).to_i
      result[name] = difference if difference.positive?
    end
  end
  private_class_method :material_difference

  def self.consume_materials!(player, materials)
    materials.each do |name, quantity|
      remaining = quantity.to_i
      player.items.where(name: name).order(:id).each do |item|
        consumed = [ item.quantity.to_i, remaining ].min
        item.quantity -= consumed
        remaining -= consumed
        item.quantity.to_i <= 0 ? item.destroy! : item.save!
        break if remaining.zero?
      end
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
