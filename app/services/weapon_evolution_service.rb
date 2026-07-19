class WeaponEvolutionService
  Result = Struct.new(:status, :message, keyword_init: true)
  Quote = Struct.new(
    :rule, :weapon, :conditions_met, :condition_summaries,
    :smith_proficiency, :required_smith_proficiency, :smith_ready,
    :required_col, :required_items, :materials_ready, :col_ready,
    :level_ready, :floor_ready,
    keyword_init: true
  ) do
    def executable?
      conditions_met && smith_ready && materials_ready && col_ready && level_ready && floor_ready
    end
  end

  def self.eligible_rule_for(weapon)
    return nil unless weapon&.evolvable_origin?

    WeaponEvolutionRule.find_by(source_weapon_name: weapon.name)
  end

  def self.quote_for(player, weapon, blacksmith_mode: "npc", blacksmith: nil)
    rule = eligible_rule_for(weapon)
    return nil unless rule

    context = BlacksmithService.context_for(player, mode: blacksmith_mode, blacksmith: blacksmith)
    smith_proficiency = context&.proficiency.to_i

    Quote.new(
      rule: rule,
      weapon: weapon,
      conditions_met: rule.conditions_met?(weapon),
      condition_summaries: rule.condition_summaries(weapon),
      smith_proficiency: smith_proficiency,
      required_smith_proficiency: rule.required_smith_proficiency.to_i,
      smith_ready: context.present? && smith_proficiency >= rule.required_smith_proficiency.to_i,
      required_col: rule.required_col,
      required_items: rule.required_items,
      materials_ready: materials_available?(player, rule.required_items),
      col_ready: player.col.to_i >= rule.required_col,
      level_ready: player.level.to_i >= rule.required_player_level.to_i,
      floor_ready: rule.required_floor.blank? || player.floor.to_i >= rule.required_floor.to_i
    )
  end

  def self.evolve!(player, weapon, blacksmith_mode: "npc", blacksmith: nil)
    return Result.new(status: :error, message: "その武器は所持していません。") unless weapon&.player_id == player.id

    rule = eligible_rule_for(weapon)
    return Result.new(status: :error, message: "進化できる武器ではありません。") unless rule
    return Result.new(status: :error, message: "進化条件をまだ満たしていません。") unless rule.conditions_met?(weapon)
    return Result.new(status: :error, message: "鍛冶屋「お前にはまだ早い」") if player.level.to_i < rule.required_player_level.to_i
    if rule.required_floor.present? && player.floor.to_i < rule.required_floor.to_i
      return Result.new(status: :error, message: "この階層ではまだ進化させられない。")
    end

    context = BlacksmithService.context_for(player, mode: blacksmith_mode, blacksmith: blacksmith)
    return Result.new(status: :error, message: "鍛冶を行える実行者がいません。") unless context
    if context.proficiency.to_i < rule.required_smith_proficiency.to_i
      return Result.new(status: :error, message: "この進化を扱うには鍛冶の技量が足りない。（必要熟練度#{rule.required_smith_proficiency}）")
    end
    return Result.new(status: :error, message: "刻銭が足りません。進化には#{rule.required_col}刻銭必要です。") if player.col.to_i < rule.required_col

    missing = rule.required_items.find { |name, quantity| player.items.where(name: name).sum(:quantity).to_i < quantity.to_i }
    return Result.new(status: :error, message: "素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    target_name = rule.target_weapon_name
    insufficient_after_lock = false
    ActiveRecord::Base.transaction do
      player.lock!
      weapon.lock!
      still_missing = rule.required_items.find { |name, quantity| player.items.where(name: name).sum(:quantity).to_i < quantity.to_i }
      if still_missing || player.col.to_i < rule.required_col
        insufficient_after_lock = true
        raise ActiveRecord::Rollback
      end

      consume_materials!(player, rule.required_items)
      player.col = player.col.to_i - rule.required_col
      weapon.update!(
        name: target_name,
        enhancement_level: 0,
        enhance_attempts: 0,
        sharpness_level: 0,
        quickness_level: 0,
        accuracy_level: 0,
        heaviness_level: 0,
        durability_level: 0,
        durability_loss_remainder: 0,
        critical_hit_count: 0,
        kill_count: 0,
        durability: [ weapon.durability.to_i, weapon.max_durability.to_i ].min
      )
      player.save!
      BlacksmithProficiencyService.award!(context, task_difficulty: rule.required_smith_proficiency.to_i, action: :evolve)
    end
    return Result.new(status: :error, message: "素材または刻銭が不足しています。もう一度お試しください。") if insufficient_after_lock

    Result.new(status: :ok, message: "#{target_name}へ進化した。")
  end

  def self.materials_available?(player, materials)
    materials.all? { |name, quantity| player.items.where(name: name).sum(:quantity).to_i >= quantity.to_i }
  end
  private_class_method :materials_available?

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
end
