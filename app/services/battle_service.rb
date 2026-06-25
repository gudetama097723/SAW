class BattleService
  Result = Struct.new(:status, :message, keyword_init: true)

  def self.ensure_mob_parts!(mob)
    return [] unless mob
    if mob.boss?
      ensure_boss_parts!(mob)
      return mob.mob_parts.to_a
    end
    return mob.mob_parts.to_a if mob.mob_parts.exists?

    mob.mob_parts.create!(name: "本体", damage_multiplier: 100, weakness: true)
    mob.mob_parts.to_a
  end

  def self.ensure_boss_parts!(mob)
    boss_part_templates_for(mob).each do |attrs|
      part = mob.mob_parts.find_or_initialize_by(name: attrs[:name])
      part.update!(attrs)
    end
    mob.mob_parts.where(name: "本体").destroy_all if mob.mob_parts.where.not(name: "本体").exists?
  end

  def self.boss_part_templates_for(mob)
    case mob.name
    when "群狼の王"
      [
        { name: "頭", damage_multiplier: 115, weakness: true, max_durability: 42, drop_item_name: "狼王の牙", drop_rate: 35, weak_attack_attribute: "刺突" },
        { name: "胴体", damage_multiplier: 80, weakness: false, max_durability: 70, weak_attack_attribute: "斬撃" },
        { name: "前脚", damage_multiplier: 85, weakness: false, max_durability: 38, break_effect: "strength_down", weak_attack_attribute: "打撃" },
        { name: "後脚", damage_multiplier: 75, weakness: false, max_durability: 34, break_effect: "agility_down", weak_attack_attribute: "刺突" }
      ]
    when "蒼狼フェンリル"
      [
        { name: "額の蒼角", damage_multiplier: 125, weakness: true, max_durability: 68, drop_item_name: "蒼狼の牙", drop_rate: 30, weak_attack_attribute: "打撃" },
        { name: "胴体", damage_multiplier: 78, weakness: false, max_durability: 120, weak_attack_attribute: "斬撃" },
        { name: "前脚", damage_multiplier: 85, weakness: false, max_durability: 72, break_effect: "strength_down", weak_attack_attribute: "打撃" },
        { name: "後脚", damage_multiplier: 75, weakness: false, max_durability: 64, break_effect: "agility_down", weak_attack_attribute: "刺突" },
        { name: "尾", damage_multiplier: 70, weakness: false, max_durability: 58, drop_item_name: "狼王の牙", drop_rate: 18, weak_attack_attribute: "斬撃" }
      ]
    else
      [
        { name: "弱点", damage_multiplier: 115, weakness: true, max_durability: 50 },
        { name: "胴体", damage_multiplier: 80, weakness: false, max_durability: 80 },
        { name: "腕", damage_multiplier: 85, weakness: false, max_durability: 45, break_effect: "strength_down" },
        { name: "脚", damage_multiplier: 75, weakness: false, max_durability: 45, break_effect: "agility_down" }
      ]
    end
  end

  def self.resolve_player_attack!(battle:, player:, mob_part_id:, target_enemy_id: nil, group_start: nil, label:, damage_multiplier:, durability_cost:, skill_gain:, stiffness:, hits:, sword_skill:, area: false, attack_attribute: nil, skill_key: nil)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    weapon = player.equipped_weapon
    return Result.new(status: :error, message: "武器を装備していないため、ソードスキルは使用できません。") if sword_skill && !weapon

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0
    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, weapon, label, turn_messages.join, skill_gain, sword_skill, skill_key)
    end

    blocked_message = StatusEffectService.action_blocked_message!(player)
    if blocked_message
      BuffEffectService.tick_battle_turn!(player)
      player.save!
      enemy_result = apply_enemy_attack!(player, battle)
      return enemy_result if enemy_result.status == :defeated

      return Result.new(status: :ok, message: "#{turn_messages.join}#{blocked_message}#{enemy_result.message}")
    end

    target_enemies = target_enemies_for(battle, target_enemy_id, group_start, area)
    return Result.new(status: :error, message: "攻撃対象がいません。") if target_enemies.empty?

    hit_messages = []
    actual_attack_attribute = attack_attribute_for(weapon, attack_attribute, sword_skill)
    record_normal_attack_use!(player, weapon) if weapon && !sword_skill

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
          damage_multiplier: per_target_multiplier,
          attack_attribute: actual_attack_attribute
        )
        hit_messages << hit_message(index, hits, result)
      end
    end

    battle.update!(ambush: false) if battle.ambush?

    weapon&.apply_durability_loss!(durability_loss_for(weapon, durability_cost, actual_attack_attribute))

    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, weapon, label, hit_messages.join(" / "), skill_gain, sword_skill, skill_key)
    end

    skill_message = sword_skill ? gain_sword_skill_use!(player, weapon, skill_key, skill_gain) : ""

    BuffEffectService.tick_battle_turn!(player)
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
      message: "#{turn_messages.join}#{label}！#{hit_messages.join(' / ')}！#{enemy_result.message}#{stiffness_message}#{broken_message}#{skill_message}"
    )
  end

  def self.apply_enemy_attack!(player, battle, prefix: "", allow_evasion: true)
    return Result.new(status: :ok, message: "") if battle.destroyed?

    ensure_battle_enemies!(battle)
    messages = []

    battle.alive_enemies.each do |battle_enemy|
      mob_name = battle_enemy.mob.name
      blocked_message = StatusEffectService.action_blocked_message!(battle_enemy)
      if blocked_message
        BuffEffectService.tick_battle_turn!(battle_enemy)
        battle_enemy.save!
        messages << enemy_message("#{prefix}#{blocked_message}")
        next
      end

      if enemy_flees?(battle_enemy)
        BuffEffectService.tick_battle_turn!(battle_enemy)
        battle_enemy.destroy!
        messages << enemy_message("#{prefix}#{mob_name}は逃走した！")
        next
      end

      if allow_evasion && evaded_enemy_attack?(player, battle_enemy)
        BuffEffectService.tick_battle_turn!(battle_enemy)
        battle_enemy.save!
        messages << enemy_message("#{prefix}#{mob_name}の攻撃を回避した！")
        next
      end

      raw_damage = rand(1..mob_effective_atk(battle_enemy))
      enemy_damage = [raw_damage - player.damage_cut, 1].max
      enemy_damage = (enemy_damage * StatusEffectService.damage_dealt_multiplier(battle_enemy)).ceil
      enemy_damage = (enemy_damage * StatusEffectService.damage_taken_multiplier(player)).ceil
      enemy_damage = (enemy_damage * BuffEffectService.defense_damage_taken_multiplier(player)).ceil
      critical = StatusEffectService.sleeping_critical!(player)
      enemy_damage *= 2 if critical
      player.hp = player.hp.to_i - enemy_damage
      apply_mob_status_attacks!(player, battle_enemy)

      if player.hp <= 0
        critical_message = critical ? "クリティカル！" : ""
        return handle_player_defeat!(player, battle, "#{enemy_message("#{prefix}#{mob_name}の攻撃！#{critical_message}#{enemy_damage}ダメージを受けた！")}あなたは倒れた……。")
      end

      critical_message = critical ? "クリティカル！" : ""
      BuffEffectService.tick_battle_turn!(battle_enemy)
      battle_enemy.save!
      messages << enemy_message("#{prefix}#{mob_name}の攻撃！#{critical_message}#{enemy_damage}ダメージを受けた！")
    end

    player.save!
    if battle.alive_enemies.reload.empty?
      battle.destroy!
      messages << "敵はいなくなった。"
    end

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

  def self.resolve_hit!(player:, weapon:, battle_enemy:, mob_part_id:, damage_multiplier:, attack_attribute:)
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

    base_hit_damage = (calculate_player_damage(player, weapon, battle_enemy, actual_part, attack_attribute) * damage_multiplier / 100.0).ceil
    varied_damage = apply_player_damage_variance(base_hit_damage)
    part_damage = calculate_part_damage(varied_damage, weapon, actual_part)
    critical = StatusEffectService.sleeping_critical!(battle_enemy) || critical_hit?(player, weapon, battle_enemy, actual_part, part_damage)
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

def self.calculate_player_damage(player, weapon, battle_enemy, part, attack_attribute)
  weapon_power = weapon&.effective_attack_power.to_i
  stat_power = weapon ? weapon.stat_attack_power(player) : player.effective_strength
  attack_power = (stat_power * 0.7) + (weapon_power * 1.3)
  attack_power *= attribute_multiplier(weapon, battle_enemy.mob, part, attack_attribute)
  attack_power *= weapon_proficiency_attack_bonus(player, weapon)
  attack_power *= BuffEffectService.attack_multiplier(player)
  defense_rate = 100.0 / (100 + [battle_enemy.effective_durability, 0].max)
  base_damage = attack_power * defense_rate
  base_damage *= StatusEffectService.damage_dealt_multiplier(player)
  base_damage *= StatusEffectService.damage_taken_multiplier(battle_enemy)
  base_damage *= BuffEffectService.defense_damage_taken_multiplier(battle_enemy)
  [(base_damage * part.damage_multiplier.to_i / 100.0).ceil, 1].max
end

def self.attribute_multiplier(weapon, mob, part, attack_attribute)
  attribute = AttackAttribute.normalize(attack_attribute)
  multiplier = 1.0
  multiplier *= 1.2 if weapon&.matches_attack_attribute?(attribute)
  multiplier *= 1.5 if mob&.weak_to_attribute?(attribute)
  multiplier *= 1.5 if part&.weak_to_attribute?(attribute)
  multiplier
end

def self.attack_attribute_for(weapon, attack_attribute, sword_skill)
  return AttackAttribute.normalize(attack_attribute) if attack_attribute.present?

  sword_skill ? weapon&.primary_attack_attribute || "斬撃" : weapon&.primary_attack_attribute || "斬撃"
end

  def self.weapon_proficiency_attack_bonus(player, weapon)
  return 1.0 unless weapon

  skill = player.skills.find_by(name: weapon_skill_name(weapon))
  1.0 + (skill&.proficiency.to_i / 1000.0 * 0.15)
end

  def self.player_attack_hit?(player, battle_enemy, part)
    player_agility = (player.effective_agility * BuffEffectService.agility_multiplier(player)).round
    agility_gap = player_agility - mob_effective_agility(battle_enemy)
    part_modifier = part.weakness? ? -10 : 0
    ambush_bonus = battle_enemy.battle.ambush? ? 15 : 0

    return true if BuffEffectService.sure_hit?(player)

    chance = 85 + (agility_gap * 3) + part_modifier + ambush_bonus
    chance += BuffEffectService.accuracy_modifier(player)
    chance -= BuffEffectService.accuracy_modifier(battle_enemy)
    chance = chance.clamp(55, 98)

    rand(100) < chance
  end

  def self.durability_loss_for(weapon, base_cost, attack_attribute)
    return base_cost.to_i unless weapon
    return base_cost.to_i if weapon.matches_attack_attribute?(attack_attribute)

    [base_cost.to_i * 2, base_cost.to_i + 1].max
  end

  def self.apply_death_item_penalty!(player)
    candidates = player.items.reject(&:protected_item?).flat_map do |item|
      Array.new(item.quantity.to_i) { item }
    end
    return "" if candidates.empty?

    lost_count = (candidates.size / 2.0).floor
    return "" if lost_count <= 0

    lost = candidates.sample(lost_count).tally
    lost.each do |item, count|
      item.quantity = [item.quantity.to_i - count, 0].max
      item.quantity.zero? ? item.destroy! : item.save!
    end
    " 所持アイテムを#{lost_count}個失った。"
  end

  def self.handle_player_defeat!(player, battle, prefix_message)
    respawn_location = player.death_respawn_location
    player.hp = player.effective_max_hp
    player.floor = respawn_location&.floor || 1
    player.col = 0
    player.location = respawn_location if respawn_location
    player.field_route = nil
    player.field_position = 0
    BuffEffectService.clear_battle_effects!(player)
    lost_message = apply_death_item_penalty!(player)
    battle.destroy!
    player.save!

    respawn_name = respawn_location ? "#{respawn_location.name}の宿" : "本拠地の宿"
    Result.new(status: :defeated, message: "#{prefix_message}#{respawn_name}へ戻された。#{lost_message}")
  end

  def self.apply_battle_turn_start_effects!(player, battle)
    messages = []
    message = StatusEffectService.apply_battle_turn_start!(player)
    messages << message if message.present?

    battle.alive_enemies.each do |battle_enemy|
      message = StatusEffectService.apply_battle_turn_start!(battle_enemy)
      next if message.blank?

      battle_enemy.enemy_hp = 0 if battle_enemy.enemy_hp.to_i <= 0
      battle_enemy.save!
      messages << message
    end

    messages
  end

  def self.apply_mob_status_attacks!(player, battle_enemy)
    battle_enemy.mob.status_attacks.each do |status, amount|
      StatusEffectService.accumulate!(player, status, amount)
    end
  end

  def self.finish_battle_victory!(player, battle, weapon, label, damage_message, skill_gain, sword_skill, skill_key)
    defeated_enemies = battle.battle_enemies.includes(:mob).to_a
    col_reward = defeated_enemies.sum(&:col_reward)
    player.col = player.col.to_i + col_reward
    player.save!
    dropped_weapon_message = defeated_enemies.map { |enemy| try_drop_weapon!(player, enemy.mob) }.join
    dropped_item_message = defeat_drop_message!(player, defeated_enemies)
    broken_part_drop_message = broken_part_drop_message!(player, defeated_enemies)
    boss_reward_message = defeated_enemies.map { |enemy| ExplorationRewardService.boss_victory_message!(player, enemy.mob) }.join
    exp_message = gain_exp_message(player, defeated_enemies)
    skill_message = gain_weapon_skill_for_victory!(player, weapon, defeated_enemies.count, skill_gain, sword_skill, skill_key)
    BuffEffectService.clear_battle_effects!(player)
    player.save!
    battle.destroy!

    broken_message = destroy_weapon_if_broken!(weapon)
    victory_message = defeated_enemies.many? ? "敵を全て倒した！" : ""
    Result.new(status: :ok, message: "#{label}！#{damage_message}！#{victory_message}#{col_reward}コル獲得！#{exp_message}#{boss_reward_message}#{dropped_item_message}#{broken_part_drop_message}#{dropped_weapon_message}#{broken_message}#{skill_message}")
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

      item = ItemService.add_item!(player, drop.item_name, drop.category, 1, unique: battle_enemy.mob.boss?)
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

        item = ItemService.add_item!(player, item_name, "drop", 1, unique: battle_enemy.mob.boss?)
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
    player_agility = (player.effective_agility * BuffEffectService.agility_multiplier(player)).round
    agility_gap = player_agility - mob_effective_agility(battle_enemy)
    weight_penalty = player.overweight? ? (player.overweight_amount * 2).ceil : 0
    chance = [[10 + (agility_gap * 5) - weight_penalty, 5].max, 75].min
    rand(100) < chance
  end

  def self.enemy_flees?(battle_enemy)
    rate = battle_enemy.mob.effective_flee_rate
    rate.positive? && rand(100) < rate
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

def self.gain_weapon_skill_for_victory!(player, weapon, defeated_count, use_exp, sword_skill, skill_key)
  return "" unless weapon

  growth = SkillGrowthCatalog.find(weapon_skill_name(weapon))
  amount = growth.kill_exp.to_i * defeated_count.to_i
  amount += use_exp.to_i if sword_skill
  amount += growth.sword_skill_kill_bonus.to_i * defeated_count.to_i if sword_skill
  message = gain_weapon_skill!(player, weapon, amount)
  message += gain_sword_skill_use!(player, weapon, skill_key, use_exp.to_i) if sword_skill
  message
end

def self.gain_sword_skill_use!(player, weapon, skill_key, amount)
  return "" unless weapon && skill_key.present? && amount.to_i.positive?

  skill = player.skills.find_by(name: weapon_skill_name(weapon))
  return "" unless skill

  before_level = skill.sword_skill_level(skill_key)
  after_level = skill.gain_sword_skill_exp!(skill_key, amount)
  after_level > before_level ? " #{SkillCatalog.find(skill_key).name} Lv.#{after_level}に上昇した！" : ""
end

def self.gain_weapon_skill!(player, weapon, amount)

    return "" unless weapon
    return "" if amount.to_i <= 0

    skill_name = weapon_skill_name(weapon)
    growth = SkillGrowthCatalog.find(skill_name)
    skill = player.skills.find_by(name: skill_name)
    return "" unless skill

    before = skill.proficiency.to_i
    awarded_capstone_slot = skill.gain_skill_exp!(amount, growth_scale: growth.growth_scale)

    learned = SkillCatalog.sword_skills(skill_name).select do |skill_definition|
      skill_definition.required_proficiency.positive? &&
        before < skill_definition.required_proficiency &&
        skill.proficiency >= skill_definition.required_proficiency
    end.map(&:name)
    learned_message = learned.map do |name|
      learned_skill = SkillCatalog.sword_skills(skill_name).find { |skill_definition| skill_definition.name == name }
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
      "片手直剣"
    when "細剣"
      "細剣"
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

  def self.record_normal_attack_use!(player, weapon)
    player.increment_skill_counter!(SkillUnlockService.weapon_attack_counter_key(weapon_skill_name(weapon)))
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
