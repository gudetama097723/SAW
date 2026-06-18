class BattleService
  Result = Struct.new(:status, :message, keyword_init: true)

  def self.ensure_mob_parts!(mob)
    return [] unless mob
    return mob.mob_parts.to_a if mob.mob_parts.exists?

    mob.mob_parts.create!(name: "本体", damage_multiplier: 100, weakness: true)
    mob.mob_parts.to_a
  end

  def self.resolve_player_attack!(battle:, player:, mob_part_id:, target_enemy_id: nil, group_start: nil, label:, damage_multiplier:, durability_cost:, skill_gain:, stiffness:, hits:, sword_skill:, area: false)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    weapon = player.equipped_weapon
    return Result.new(status: :error, message: "武器を装備していないため、ソードスキルは使用できません。") if sword_skill && !weapon

    ensure_battle_enemies!(battle)
    target_enemies = target_enemies_for(battle, target_enemy_id, group_start, area)
    return Result.new(status: :error, message: "攻撃対象がいません。") if target_enemies.empty?

    hit_messages = []

    hits.times do |index|
      alive_targets = target_enemies.select(&:alive?)
      break if alive_targets.empty?

      per_target_multiplier = area_damage_multiplier(damage_multiplier, alive_targets.size)
      alive_targets.each do |battle_enemy|
        result = resolve_hit!(
          player: player,
          weapon: weapon,
          battle_enemy: battle_enemy,
          mob_part_id: (alive_targets.one? ? mob_part_id : nil),
          damage_multiplier: per_target_multiplier
        )
        hit_messages << hit_message(index, hits, result)
      end
    end

    battle.update!(ambush: false) if battle.ambush?

    weapon&.apply_durability_loss!(durability_cost)

    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, weapon, label, hit_messages.join(" / "), skill_gain, sword_skill)
    end

    skill_message = sword_skill ? gain_weapon_skill!(player, weapon, skill_gain) : ""

    player.save!
    battle.save!
    broken_message = destroy_weapon_if_broken!(weapon)
    enemy_result = apply_enemy_attack!(player, battle)
    return enemy_result if enemy_result.status == :defeated

    stiffness_message = ""
    if stiffness
      stiffness_result = apply_enemy_attack!(player, battle, prefix: "ソードスキル後の硬直中、", allow_evasion: false)
      return stiffness_result if stiffness_result.status == :defeated

      stiffness_message = stiffness_result.message
    end

    Result.new(
      status: :ok,
      message: "#{label}！#{hit_messages.join(' / ')}！#{enemy_result.message}#{stiffness_message}#{broken_message}#{skill_message}"
    )
  end

  def self.apply_enemy_attack!(player, battle, prefix: "", allow_evasion: true)
    ensure_battle_enemies!(battle)
    messages = []

    battle.alive_enemies.each do |battle_enemy|
      mob_name = battle_enemy.mob.name
      if allow_evasion && evaded_enemy_attack?(player, battle_enemy)
        messages << enemy_message("#{prefix}#{mob_name}の攻撃を回避した！")
        next
      end

      raw_damage = rand(1..mob_effective_atk(battle_enemy))
      enemy_damage = [raw_damage - player.damage_cut, 1].max
      player.hp = player.hp.to_i - enemy_damage

      if player.hp <= 0
        town = Location.find_by(name: "はじまりの街")
        player.hp = player.effective_max_hp
        player.floor = 1
        player.col = 0
        player.location = town if town
        battle.destroy!
        player.save!

        return Result.new(status: :defeated, message: "#{enemy_message("#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！")}あなたは倒れた……。はじまりの街へ戻された。")
      end

      messages << enemy_message("#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！")
    end

    player.save!
    Result.new(status: :ok, message: messages.join)
  end

  def self.ensure_part_states!(battle, parts)
    states = battle_part_states(battle)
    changed = false
    parts.each do |part|
      next if states.key?(part.id.to_s)

      states[part.id.to_s] = default_part_state(part)
      changed = true
    end
    return states unless changed

    battle.part_states = states.to_json
    battle.save!
    states
  end

  def self.battle_part_states(battle)
    JSON.parse(battle.part_states.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def self.ensure_battle_enemies!(battle)
    return battle.alive_enemies.to_a if battle.battle_enemies.exists?

    enemy_level = [battle.mob.level.to_i, 1].max
    enemy_max_hp = FieldService.scaled_mob_value(battle.mob.hp, enemy_level)
    battle.battle_enemies.create!(
      FieldService.battle_enemy_attributes(
        mob: battle.mob,
        enemy_hp: battle.enemy_hp || enemy_max_hp,
        enemy_max_hp: enemy_max_hp,
        enemy_level: enemy_level,
        position: 1
      )
    )
    battle.alive_enemies.to_a
  end

  def self.target_enemies_for(battle, target_enemy_id, group_start, area)
    alive = battle.alive_enemies.to_a
    if area
      start = group_start.to_i
      start = alive.first&.position.to_i if start <= 0
      alive.select { |enemy| enemy.position >= start && enemy.position < start + 4 }.first(4)
    elsif target_enemy_id.present?
      alive.select { |enemy| enemy.id == target_enemy_id.to_i }
    else
      alive.first ? [alive.first] : []
    end
  end

  def self.resolve_hit!(player:, weapon:, battle_enemy:, mob_part_id:, damage_multiplier:)
    parts = ensure_mob_parts!(battle_enemy.mob)
    ensure_part_states!(battle_enemy, parts)
    target_part = if mob_part_id.present?
                    parts.find { |mob_part| mob_part.id == mob_part_id.to_i } || parts.first
                  else
                    weighted_random_part(parts, battle_enemy)
                  end
    return "#{battle_enemy.mob.name}に攻撃可能部位がない" unless target_part

    guard_result = resolve_guarded_part(player, battle_enemy, parts, target_part)
    return "#{battle_enemy.mob.name}: #{guard_result[:message]}" if guard_result[:blocked]

    actual_part = guard_result[:part]
    unless player_attack_hit?(player, battle_enemy, actual_part)
      return "#{battle_enemy.mob.name}: #{guard_result[:message]}ミス"
    end

    base_hit_damage = (calculate_player_damage(player, weapon, battle_enemy, actual_part) * damage_multiplier / 100.0).ceil
    varied_damage = apply_player_damage_variance(base_hit_damage)
    part_damage = calculate_part_damage(varied_damage, weapon, actual_part)
    critical = critical_hit?(player, weapon, battle_enemy, actual_part, part_damage)
    hit_damage = critical ? varied_damage * 2 : varied_damage
    battle_enemy.enemy_hp = [battle_enemy.enemy_hp.to_i - hit_damage, 0].max
    break_message = apply_part_damage!(player, battle_enemy, actual_part, part_damage)
    battle_enemy.save!

    critical_message = critical ? "クリティカル！" : ""
    defeated_message = battle_enemy.enemy_hp <= 0 ? " #{battle_enemy.mob.name}を倒した！" : ""
    "#{battle_enemy.mob.name}: #{guard_result[:message]}#{critical_message}#{actual_part.name}へ#{hit_damage}ダメージ#{break_message}#{defeated_message}"
  end

  def self.weighted_random_part(parts, battle_enemy)
    candidates = parts.reject { |part| part_broken?(battle_enemy, part) }
    candidates = parts if candidates.empty?
    weighted = candidates.flat_map do |part|
      weight = part.weakness? ? 1 : [part.damage_multiplier.to_i / 20, 1].max
      [part] * weight
    end
    weighted.sample || candidates.first
  end

  def self.area_damage_multiplier(damage_multiplier, target_count)
    reduction = { 1 => 1.0, 2 => 0.75, 3 => 0.62, 4 => 0.52, 5 => 0.45 }.fetch(target_count, 0.5)
    (damage_multiplier * reduction).ceil
  end

  def self.calculate_player_damage(player, weapon, battle_enemy, part)
    weapon_power = weapon&.attack_power.to_i
    attack_power = (player.effective_strength * 0.7) + (weapon_power * 1.3)
    defense_rate = 100.0 / (100 + [battle_enemy.effective_durability, 0].max)
    base_damage = attack_power * defense_rate
    [(base_damage * part.damage_multiplier.to_i / 100.0).ceil, 1].max
  end

  def self.player_attack_hit?(player, battle_enemy, part)
    agility_gap = player.effective_agility - mob_effective_agility(battle_enemy)
    part_modifier = part.weakness? ? -10 : 0
    ambush_bonus = battle_enemy.battle.ambush? ? 15 : 0

    chance = 85 + (agility_gap * 3) + part_modifier + ambush_bonus
    chance = chance.clamp(55, 98)

    rand(100) < chance
  end

  def self.finish_battle_victory!(player, battle, weapon, label, damage_message, skill_gain, sword_skill)
    defeated_enemies = battle.battle_enemies.includes(:mob).to_a
    col_reward = defeated_enemies.sum(&:col_reward)
    player.col = player.col.to_i + col_reward
    player.save!
    dropped_weapon_message = defeated_enemies.map { |enemy| try_drop_weapon!(player, enemy.mob) }.join
    dropped_item_message = defeat_drop_message!(player, defeated_enemies)
    broken_part_drop_message = broken_part_drop_message!(player, defeated_enemies)
    exp_message = gain_exp_message(player, defeated_enemies)
    skill_message = gain_weapon_skill_for_victory!(player, weapon, defeated_enemies.count, skill_gain, sword_skill)
    battle.destroy!

    broken_message = destroy_weapon_if_broken!(weapon)
    victory_message = defeated_enemies.many? ? "敵を全て倒した！" : ""
    Result.new(status: :ok, message: "#{label}！#{damage_message}！#{victory_message}#{col_reward}コル獲得！#{exp_message}#{dropped_item_message}#{broken_part_drop_message}#{dropped_weapon_message}#{broken_message}#{skill_message}")
  end

  def self.hit_message(index, hits, message)
    hits > 1 ? "#{index + 1}撃目 #{message}" : message
  end

  def self.apply_player_damage_variance(damage)
    [(damage.to_i * rand(75..100) / 100.0).ceil, 1].max
  end

  def self.calculate_part_damage(hp_damage, weapon, part)
    weapon_break_power = weapon&.effective_part_break_power || 100
    part_modifier = part.weakness? ? 0.8 : 1.0
    [(hp_damage.to_i * 0.35 * weapon_break_power / 100.0 * part_modifier).ceil, 1].max
  end

  def self.critical_hit?(player, weapon, battle_enemy, part, damage)
    return false unless weapon
    return true if part.weakness? && part_would_break?(battle_enemy, part, damage)

    agility_bonus = (player.effective_agility - mob_effective_agility(battle_enemy)) / 5
    chance = [[weapon.effective_critical_rate + agility_bonus, 1].max, 30].min
    rand(100) < chance
  end

  def self.part_would_break?(battle_enemy, part, damage)
    state = battle_part_states(battle_enemy)[part.id.to_s] || default_part_state(part)
    return false if state["broken"]

    state["durability"].to_i <= damage.to_i
  end

  def self.resolve_guarded_part(player, battle_enemy, parts, target_part)
    return { part: target_part, message: "", blocked: false } if part_broken?(battle_enemy, target_part)
    return { part: target_part, message: "", blocked: false } unless enemy_guard_success?(player, battle_enemy, target_part)

    if battle_enemy.mob.equipped_weapon && target_part.weakness?
      return { part: target_part, message: "#{battle_enemy.mob.equipped_weapon.name}で弾かれた！", blocked: true }
    end

    guard_part = guard_part_for(battle_enemy, parts, target_part)
    guard_part ? { part: guard_part, message: "#{guard_part.name}で防がれた！", blocked: false } : { part: target_part, message: "", blocked: false }
  end

  def self.enemy_guard_success?(player, battle_enemy, target_part)
    base_chance = target_part.weakness? ? 65 : 20
    base_chance += 15 if battle_enemy.mob.equipped_weapon && target_part.weakness?
    agility_gap = player.effective_agility - mob_effective_agility(battle_enemy)
    chance = [[base_chance - (agility_gap * 6), 5].max, 90].min
    rand(100) < chance
  end

  def self.guard_part_for(battle_enemy, parts, target_part)
    candidates = parts.reject { |part| part.id == target_part.id || part_broken?(battle_enemy, part) || part.weakness? }
    candidates.find { |part| part.name.match?(/手|腕/) } ||
      candidates.find { |part| part.name.match?(/外膜|胴|体/) } ||
      candidates.first
  end

  def self.apply_part_damage!(player, battle_enemy, part, damage)
    states = battle_part_states(battle_enemy)
    state = states[part.id.to_s] || default_part_state(part)
    return "" if state["broken"]

    state["durability"] = state["durability"].to_i - damage.to_i
    message = ""
    if state["durability"] <= 0
      state["broken"] = true
      message = " #{part.break_message}"
    end

    states[part.id.to_s] = state
    battle_enemy.part_states = states.to_json
    message
  end

  def self.defeat_drop_message!(player, defeated_enemies)
    messages = defeated_enemies.filter_map do |battle_enemy|
      drop = MobDropCatalog.roll_defeat_drop(battle_enemy.mob)
      next unless drop

      item = ItemService.add_item!(player, drop.item_name, drop.category)
      item.save!
      "#{drop.item_name}を入手した！"
    end

    messages.any? ? " #{messages.join}" : ""
  end

  def self.broken_part_drop_message!(player, defeated_enemies)
    messages = defeated_enemies.flat_map do |battle_enemy|
      states = battle_part_states(battle_enemy)
      battle_enemy.mob.mob_parts.filter_map do |part|
        next unless states.dig(part.id.to_s, "broken")

        item_name = MobDropCatalog.roll_part_drop(part)
        next unless item_name

        item = ItemService.add_item!(player, item_name, "drop")
        item.save!
        "#{part.name}から#{item_name}を入手した！"
      end
    end

    messages.any? ? " #{messages.join}" : ""
  end

  def self.default_part_state(part)
    { "durability" => part.max_durability.to_i, "broken" => false }
  end

  def self.part_broken?(battle, part)
    battle_part_states(battle).dig(part.id.to_s, "broken") == true
  end

  def self.mob_effective_atk(battle_enemy)
    penalty = broken_parts_with_effect(battle_enemy, "strength_down").count * 0.35
    [(battle_enemy.effective_atk * (1.0 - penalty)).ceil, 1].max
  end

  def self.mob_effective_agility(battle_enemy)
    penalty = broken_parts_with_effect(battle_enemy, "agility_down").count * 0.35
    [(battle_enemy.effective_agility * (1.0 - penalty)).ceil, 1].max
  end

  def self.broken_parts_with_effect(battle_enemy, effect)
    battle_enemy.mob.mob_parts.select { |part| part.break_effect == effect && part_broken?(battle_enemy, part) }
  end

  def self.evaded_enemy_attack?(player, battle_enemy)
    agility_gap = player.effective_agility - mob_effective_agility(battle_enemy)
    chance = [[10 + (agility_gap * 5), 5].max, 75].min
    rand(100) < chance
  end

  def self.gain_exp_message(player, defeated_enemies)
    before_level = player.level.to_i
    before_slots = player.skill_slots.to_i

    total = Array(defeated_enemies).sum do |battle_enemy|
      amount = adjusted_exp_reward(player, battle_enemy)
      player.gain_exp!(amount)
      amount
    end

    message = "経験値を #{total} 獲得した！"
    level_gain = player.level.to_i - before_level
    message += " レベル#{player.level}に上昇！振り分けポイント +#{level_gain * 3}" if level_gain.positive?
    message += " スキルスロット +#{player.skill_slots.to_i - before_slots}" if player.skill_slots.to_i > before_slots
    message
  end

  def self.adjusted_exp_reward(player, battle_enemy)
    level_gap = battle_enemy.effective_level - player.effective_level
    multiplier = 1.0 + (level_gap * 0.15)
    multiplier = [[multiplier, 0.1].max, 2.5].min
    [(battle_enemy.effective_exp_reward * multiplier).round, 1].max
  end

  def self.gain_weapon_skill_for_victory!(player, weapon, defeated_count, use_exp, sword_skill)
    return "" unless weapon

    growth = SkillGrowthCatalog.find(weapon_skill_name(weapon))
    amount = growth.kill_exp.to_i * defeated_count.to_i
    amount += use_exp.to_i if sword_skill
    amount += growth.sword_skill_kill_bonus.to_i * defeated_count.to_i if sword_skill
    gain_weapon_skill!(player, weapon, amount)
  end

  def self.gain_weapon_skill!(player, weapon, amount)
    return "" unless weapon
    return "" if amount.to_i <= 0

    skill_name = weapon_skill_name(weapon)
    growth = SkillGrowthCatalog.find(skill_name)
    skill = player.skills.find_or_create_by!(name: skill_name) do |new_skill|
      new_skill.proficiency = 0
      new_skill.skill_exp = 0 if new_skill.has_attribute?(:skill_exp)
    end
    before = skill.proficiency.to_i
    awarded_capstone_slot = skill.gain_skill_exp!(amount, growth_scale: growth.growth_scale)

    learned = SkillCatalog.sword_skills.select do |skill_definition|
      skill_definition.required_proficiency.positive? &&
        before < skill_definition.required_proficiency &&
        skill.proficiency >= skill_definition.required_proficiency
    end.map(&:name)
    learned_message = learned.map do |name|
      learned_skill = SkillCatalog.sword_skills.find { |skill_definition| skill_definition.name == name }
      " #{skill_name}の熟練度が #{learned_skill.required_proficiency} に到達した。新しいソードスキル「#{name}」を習得した！"
    end.join
    capstone_message = awarded_capstone_slot ? " #{skill_name}熟練度がカンストした！スキルスロット +1" : ""
    "#{learned_message}#{capstone_message}"
  end

  def self.enemy_message(message)
    "[enemy]#{message}[/enemy]"
  end

  def self.weapon_skill_name(weapon)
    case weapon.weapon_type
    when "片手直剣"
      "片手剣"
    else
      weapon.weapon_type.presence || "武器"
    end
  end

  def self.try_drop_weapon!(player, mob)
    weapon = mob.equipped_weapon
    return "" unless weapon
    return "" unless rand(100) < weapon.drop_rate.to_i

    player.weapons.create!(
      name: weapon.name,
      weapon_type: weapon.weapon_type,
      rarity: weapon.rarity,
      attack_power: weapon.attack_power,
      durability: weapon.max_durability,
      max_durability: weapon.max_durability,
      hp_bonus: weapon.hp_bonus,
      strength_bonus: weapon.strength_bonus,
      agility_bonus: weapon.agility_bonus,
      critical_rate: weapon.critical_rate,
      part_break_power: weapon.part_break_power,
      equipped: false
    )

    " #{mob.name}が#{weapon.name}を落とした！"
  end

  def self.destroy_weapon_if_broken!(weapon)
    return "" unless weapon
    unless weapon.broken?
      weapon.save!
      return ""
    end

    name = weapon.name
    weapon.destroy!
    " #{name}は耐久力が尽きて破損した。"
  end
end
