class WeaponCraftService
  Result = Struct.new(:status, :message, :weapon, :skill_exp_gained, keyword_init: true)
  Preview = Struct.new(
    :status, :message, :template, :ore, :monster_material, :support_material,
    :required_level, :available, :rarity, :fee, :quantities,
    :attack_range, :durability_range, :weight_range, :enhance_limit_range,
    keyword_init: true
  )

  def self.call(player:, blacksmith:, weapon_type:, ore_material:, monster_material:, support_material:, rng: Random)
    unless BlacksmithFacilityAccessService.available?(player)
      return error(BlacksmithFacilityAccessService.message_for(:craft))
    end
    return error("鍛冶を行える実行者がいません。") unless blacksmith
    unless BlacksmithFacilityAccessService.executor_available?(player, blacksmith)
      return error("この場所ではその鍛冶師を利用できない。")
    end

    template, ore, monster, support, resolve_error = resolve_materials(weapon_type, ore_material, monster_material, support_material)
    return error(resolve_error) if resolve_error

    materials = [ ore, monster, support ]
    required_level = materials.map(&:processing_level).max
    if blacksmith.proficiency < required_level
      return error("この素材を扱うには鍛冶の技量が足りない。（必要熟練度#{required_level}）")
    end

    quantities = {
      ore.name => template.ore_quantity,
      monster.name => template.monster_quantity,
      support.name => template.support_quantity
    }
    missing = quantities.find { |name, quantity| player.items.where(name: name).sum(:quantity).to_i < quantity }
    return error("素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    fee = fee_for(blacksmith, ore)
    return error("刻銭が足りません。生産工賃として#{fee}刻銭必要です。") if player.col.to_i < fee

    generated = CraftedWeaponStatGenerator.call(
      proficiency: blacksmith.proficiency, ore: ore, monster_material: monster,
      support_material: support, template: template, rng: rng
    )
    generated = apply_floor_enhancement_limit(generated, player.floor)
    name = CraftedWeaponNameGenerator.call(template: template, ore: ore, monster_material: monster)
    attributes = weapon_attributes(name, blacksmith, template, ore, monster, support, generated)
    attributes[:name] = SpecialCraftedWeaponResolver.resolve(attributes: attributes, materials: materials) || name

    weapon = nil
    gained = 0
    insufficient_after_lock = false
    ActiveRecord::Base.transaction do
      player.lock!
      still_missing = quantities.find { |name, quantity| player.items.where(name: name).sum(:quantity).to_i < quantity }
      if still_missing || player.col.to_i < fee
        insufficient_after_lock = true
        raise ActiveRecord::Rollback
      end

      consume_materials!(player, quantities)
      player.col = player.col.to_i - fee
      player.advance_time!(60)
      weapon = player.weapons.create!(attributes)
      player.save!
      gained = BlacksmithProficiencyService.award!(
        blacksmith, task_difficulty: [ required_level, ore.craft_rank * 10 ].max, action: :craft
      )
    end
    return error("素材または刻銭が不足しています。もう一度お試しください。") if insufficient_after_lock

    fee_text = blacksmith.player? ? "工賃なし" : "工賃#{fee}刻銭"
    Result.new(
      status: :ok, weapon: weapon, skill_exp_gained: gained,
      message: "――武器生産完了。《#{weapon.name}》 攻撃力#{weapon.attack_power}／耐久値#{weapon.max_durability}／重量#{weapon.weight.to_i}／強化試行上限#{weapon.enhance_limit}（#{fee_text}）"
    )
  end

  def self.fee_for(blacksmith, ore)
    return 0 if blacksmith.player?

    [ (200 + ore.craft_rank * 100) * blacksmith.fee_multiplier(:craft), 1 ].max.round
  end

  # 生産フォームの選択内容から、鍛造前に見せる推定レンジ・レアリティ・工賃を計算する
  def self.preview_for(context:, weapon_type:, ore_material:, monster_material:, support_material:)
    template, ore, monster, support, resolve_error = resolve_materials(weapon_type, ore_material, monster_material, support_material)
    return Preview.new(status: :error, message: resolve_error) if resolve_error

    required_level = [ ore, monster, support ].map(&:processing_level).max
    lowest, highest = CraftedWeaponStatGenerator.range_for(
      proficiency: context.proficiency, ore: ore, monster_material: monster, support_material: support, template: template
    )
    lowest = apply_floor_enhancement_limit(lowest, context.player.floor)
    highest = apply_floor_enhancement_limit(highest, context.player.floor)

    Preview.new(
      status: :ok, template: template, ore: ore, monster_material: monster, support_material: support,
      required_level: required_level, available: context.proficiency >= required_level,
      rarity: rarity_for(ore.craft_rank), fee: fee_for(context, ore),
      quantities: {
        ore.name => template.ore_quantity,
        monster.name => template.monster_quantity,
        support.name => template.support_quantity
      },
      attack_range: [ lowest[:attack_power], highest[:attack_power] ].minmax,
      durability_range: [ lowest[:max_durability], highest[:max_durability] ].minmax,
      weight_range: [ lowest[:weight], highest[:weight] ].minmax,
      enhance_limit_range: [ lowest[:enhance_limit], highest[:enhance_limit] ].minmax
    )
  end

  def self.resolve_materials(weapon_type, ore_material, monster_material, support_material)
    template = WeaponCraftTypeCatalog.find(weapon_type)
    ore = BlacksmithMaterialCatalog.find(ore_material, category: "ore")
    monster = BlacksmithMaterialCatalog.find(monster_material, category: "monster_material")
    support = BlacksmithMaterialCatalog.find(support_material, category: "support_material")
    return [ nil, nil, nil, nil, "武器種を選択してください。" ] unless template
    return [ nil, nil, nil, nil, "鉱石素材を選択してください。" ] unless ore
    return [ nil, nil, nil, nil, "モンスター素材を選択してください。" ] unless monster
    return [ nil, nil, nil, nil, "補助素材を選択してください。" ] unless support

    [ template, ore, monster, support, nil ]
  end
  private_class_method :resolve_materials

  def self.error(message)
    Result.new(status: :error, message: message)
  end
  private_class_method :error

  def self.weapon_attributes(name, blacksmith, template, ore, monster, support, generated)
    rank = ore.craft_rank
    {
      name: name, weapon_type: template.weapon_type, rarity: rarity_for(rank),
      attack_power: generated[:attack_power], durability: generated[:durability],
      max_durability: generated[:max_durability], weight: generated[:weight],
      part_break_power: generated[:part_break_power], attack_attributes: template.attack_attributes,
      enhance_limit: generated[:enhance_limit], enhancement_difficulty: (1.0 + rank / 100.0).round(2),
      maintenance_level: [ ore.processing_level, monster.processing_level ].max,
      crafted: true, crafted_by_name: blacksmith.name, equipped: false, origin: "crafted",
      craft_data: {
        ore: ore.name, monster_material: monster.name, support_material: support.name,
        qualities: generated[:qualities], craft_rank: rank, tags: monster.craft_tags
      }.to_json,
      description: "#{ore.name}と#{monster.name}を用いて#{blacksmith.name}が鍛造した武器。"
    }
  end
  private_class_method :weapon_attributes

  def self.rarity_for(rank)
    case rank.to_i
    when 0...10 then "common"
    when 10...30 then "uncommon"
    when 30...60 then "rare"
    when 60...90 then "epic"
    else "legendary"
    end
  end
  private_class_method :rarity_for

  def self.apply_floor_enhancement_limit(attributes, floor)
    return attributes unless floor.to_i == 1

    attributes.merge(enhance_limit: [ attributes[:enhance_limit].to_i, 8 ].min)
  end
  private_class_method :apply_floor_enhancement_limit

  def self.consume_materials!(player, materials)
    materials.each do |name, required|
      remaining = required.to_i
      player.items.where(name: name).order(:id).each do |item|
        consumed = [ item.quantity.to_i, remaining ].min
        item.quantity = item.quantity.to_i - consumed
        remaining -= consumed
        item.quantity.to_i <= 0 ? item.destroy! : item.save!
        break if remaining.zero?
      end
    end
  end
  private_class_method :consume_materials!
end
