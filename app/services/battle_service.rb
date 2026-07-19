class BattleService
  Result = Struct.new(:status, :message, keyword_init: true)
  ENEMY_SWORD_SKILL_RATE = 35
  STATUS_ATTACK_VARIANCE_RANGE = 75..125
  ENEMY_SWORD_SKILL_STIFFNESS_KEY = "enemy_sword_skill_stiffness"
  ENEMY_SWORD_SKILL_STIFFNESS_CRITICAL_BONUS = 35
  BACKSTEP_ACTION_SKIP_KEY = "backstep_action_skip"
  PARRY_ACTION_SKIP_KEY = "parry_action_skip"
  MIDDLE_REACH_WEAPON_TYPES = %w[大剣 斧 槍 両手剣].freeze
  FAR_REACH_WEAPON_TYPES = %w[投擲 弓].freeze
  PARRY_BASE_RATES = {
    "shield" => 55,
    "片手直剣" => 45,
    "細剣" => 35,
    "短剣" => 50,
    "棍" => 40,
    "片手棍" => 45,
    "片手斧" => 35,
    "斧" => 28,
    "大剣" => 30,
    "両手剣" => 30,
    "槍" => 25
  }.freeze

  def self.ensure_mob_parts!(mob)
    return [] unless mob
    return mob.mob_parts.to_a if mob.mob_parts.exists?

    if mob.boss?
      boss_part_templates_for(mob).each { |attrs| mob.mob_parts.create!(attrs) }
    else
      mob.mob_parts.create!(name: "本体", damage_multiplier: 100, weakness: true)
    end
    mob.mob_parts.to_a
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

  def self.resolve_player_attack!(battle:, player:, mob_part_id:, target_enemy_id: nil, target_enemy_ids: nil, group_start: nil, label:, damage_multiplier:, durability_cost:, skill_gain:, stiffness:, hits:, sword_skill:, area: false, attack_attribute: nil, skill_key: nil, cooldown: 0)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    weapon = combat_weapon_for(player)
    return Result.new(status: :error, message: "武器を装備していないため、錬技は使用できません。") if sword_skill && !weapon
    if sword_skill && player.sword_skill_locked_out?
      return Result.new(status: :error, message: "錬技発動後の反動で、あと#{player.sword_skill_lockout_turns}ターン使用できません。")
    end
    if sword_skill && player.sword_skill_on_cooldown?(skill_key)
      return Result.new(status: :error, message: "#{SkillCatalog.find(skill_key).name}はクールタイム中です。あと#{player.sword_skill_cooldown(skill_key)}ターン使用できません。")
    end

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0
    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, weapon, label, turn_messages.join, skill_gain, sword_skill, skill_key)
    end

    blocked_message = StatusEffectService.action_blocked_message!(player)
    if blocked_message
      BuffEffectService.tick_battle_turn!(player)
      tick_sword_skill_cooldowns_for_turn!(player, battle)
      player.save!
      enemy_result = apply_enemy_attack!(player, battle)
      return enemy_result if enemy_result.status == :defeated

      return Result.new(status: :ok, message: "#{turn_messages.join}#{blocked_message}#{enemy_result.message}")
    end

    target_enemies = target_enemies_for(battle, target_enemy_id, group_start, area, target_enemy_ids, max_targets: sword_skill ? SkillCatalog.find(skill_key).max_targets : 4)
    return Result.new(status: :error, message: "攻撃対象がいません。") if target_enemies.empty?
    unreachable = target_enemies.reject { |battle_enemy| player_attack_can_close_and_reach?(weapon, battle_enemy, sword_skill: sword_skill) }
    if unreachable.any?
      names = unreachable.map { |battle_enemy| "#{battle_enemy.display_name}（#{battle_enemy.distance_label}）" }.join("、")
      return Result.new(status: :error, message: "#{names}には距離が遠く攻撃が届きません。")
    end

    approach_messages = target_enemies.filter_map { |battle_enemy| approach_for_player_attack!(weapon, battle_enemy, sword_skill: sword_skill) }
    hit_messages = []
    actual_attack_attribute = attack_attribute_for(weapon, attack_attribute, sword_skill)
    if sword_skill && weapon
      base_cooldown = cooldown
      damage_multiplier = weapon.sword_skill_damage_multiplier(damage_multiplier, hits)
      damage_multiplier = (damage_multiplier * (1.0 + SkillModEffects.sword_skill_damage_percent(player, weapon, skill_key, hits, target_enemies.first) / 100.0)).round
      SkillModEffects.consume_linked_break!(player)
      cooldown = effective_sword_skill_cooldown(player, weapon, cooldown)
      durability_cost = effective_sword_skill_durability_cost(player, weapon, skill_key, durability_cost, base_cooldown)
    end
    record_normal_attack_use!(player, weapon) if weapon && !sword_skill

    knockback_message = ""
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
          attack_attribute: actual_attack_attribute,
          sword_skill: sword_skill,
          skill_key: skill_key
        )
        hit_messages << hit_message(index, hits, result)
        if sword_skill && weapon_knockback_result?(result)
          knockback_message = "ノックバックが発生し、互いに距離を取った！"
          break
        end
      end
      break if knockback_message.present?
    end

    consume_player_ambush_opening!(battle)
    SkillModEffects.mark_trajectory_memory!(player, target_enemies.first) if SkillModEffects.one_handed_sword?(weapon) && !sword_skill && target_enemies.one?
    SkillModEffects.consume_trajectory_memory!(player) if sword_skill

    weapon&.apply_durability_loss!(durability_loss_for(weapon, durability_cost, actual_attack_attribute))
    use_exp_message = gain_weapon_use_exp!(player, weapon)

    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, weapon, label, "#{approach_messages.join}#{hit_messages.join(' / ')}#{use_exp_message}", skill_gain, sword_skill, skill_key)
    end

    skill_message = sword_skill ? gain_sword_skill_use!(player, weapon, skill_key, skill_gain) : ""

    BuffEffectService.tick_battle_turn!(player)
    player.save!
    battle.save!
    broken_message = destroy_weapon_if_broken!(weapon)
    clear_enemy_sword_skill_stiffness_for!(target_enemies)

    enemy_result =
      if sword_skill || knockback_message.present?
        Result.new(status: :ok, message: "")
      else
        apply_enemy_attack!(player, battle)
      end
    return enemy_result if enemy_result.status == :defeated

    stiffness_message = ""
    if stiffness && knockback_message.blank?
      stiffness_result = apply_enemy_attack!(
        player,
        battle,
        prefix: "錬技後の硬直中、",
        allow_evasion: false,
        incoming_damage_multiplier: SkillModEffects.stiffness_damage_taken_multiplier(player, weapon)
      )
      return stiffness_result if stiffness_result.status == :defeated

      stiffness_message = stiffness_result.message
    end

    finish_player_cooldown_turn!(player, battle, skill_key: skill_key, cooldown: cooldown, sword_skill: sword_skill)

    Result.new(
      status: :ok,
      message: "#{turn_messages.join}#{approach_messages.join}#{label}！#{hit_messages.join(' / ')}！#{knockback_message}#{enemy_result.message}#{stiffness_message}#{broken_message}#{skill_message}#{use_exp_message}"
    )
  end

  def self.apply_enemy_attack!(player, battle, prefix: "", allow_evasion: true, evasion_focus: false, except_enemy_ids: [], shield_guard: false, parry_attempt: false, parry_tool: nil, incoming_damage_multiplier: 1.0)
    return Result.new(status: :ok, message: "") if battle.destroyed?

    ensure_battle_enemies!(battle)
    messages = []

    skipped_ids = Array(except_enemy_ids).map(&:to_i)
    battle.alive_enemies.each do |battle_enemy|
      next if skipped_ids.include?(battle_enemy.id)

      mob_name = battle_enemy.mob.name
      if enemy_action_skipped_by_backstep?(battle_enemy)
        messages << enemy_message("#{prefix}#{mob_name}は踏み込みが間に合わなかった。")
        next
      end
      if enemy_action_skipped_by_parry?(battle_enemy)
        messages << enemy_message("#{prefix}#{mob_name}は体勢を崩して動けない。")
        next
      end

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

      sword_skill = enemy_sword_skill_for(battle_enemy)
      enemy_approach_message = ""
      unless enemy_attack_reaches?(battle_enemy, sword_skill: sword_skill)
        if enemy_attack_can_close_and_reach?(battle_enemy, sword_skill: sword_skill)
          before = battle_enemy.distance_label
          close_distance!(battle_enemy)
          enemy_approach_message = "#{mob_name}は距離を詰めた（#{before}→#{battle_enemy.distance_label}）。"
        else
          close_distance!(battle_enemy)
          BuffEffectService.tick_battle_turn!(battle_enemy)
          battle_enemy.save!
          messages << enemy_message("#{prefix}#{mob_name}は距離を詰めた。")
          next
        end
      end

      if parry_attempt
        parry_result = resolve_enemy_attack_parry!(player, battle, battle_enemy, sword_skill, parry_tool, prefix, enemy_approach_message)
        return parry_result if parry_result.status == :defeated

        messages << parry_result.message
        next
      end

      if !evasion_focus && !shield_guard && enemy_sword_skill_weapon_guarded?(player, battle_enemy, sword_skill)
        start_enemy_sword_skill_cooldown!(battle_enemy, sword_skill)
        battle_enemy.save!
        player.save!
        return Result.new(status: :ok, message: enemy_message("#{prefix}#{enemy_approach_message}#{mob_name}の#{enemy_attack_name(sword_skill)}を#{combat_weapon_for(player).display_name}で弾いた！ノックバックが発生し、互いに距離を取った！"))
      end

      mark_enemy_sword_skill_stiffness!(battle_enemy, sword_skill) if sword_skill
      if allow_evasion && enemy_attack_evaded?(player, battle_enemy, focused: evasion_focus)
        start_enemy_sword_skill_cooldown!(battle_enemy, sword_skill) if sword_skill
        BuffEffectService.tick_battle_turn!(battle_enemy)
        battle_enemy.save!
        counter_message = sword_skill ? " 硬直の隙を突ける！" : ""
        messages << enemy_message("#{prefix}#{enemy_approach_message}#{mob_name}の#{enemy_attack_name(sword_skill)}を回避した！#{counter_message}")
        next
      end

      enemy_damage = (enemy_attack_damage(player, battle_enemy, sword_skill, shield_guard: shield_guard) * incoming_damage_multiplier.to_f).ceil
      player.hp = player.hp.to_i - enemy_damage
      apply_mob_status_attacks!(player, battle_enemy)
      guard_message = shield_guard ? "盾で受け、" : ""

      if player.hp <= 0
        return handle_player_defeat!(player, battle, "#{enemy_message("#{prefix}#{enemy_approach_message}#{mob_name}の#{enemy_attack_name(sword_skill)}！#{enemy_skill_hit_text(sword_skill)}#{guard_message}#{enemy_damage}ダメージを受けた！")}あなたは倒れた……。")
      end

      BuffEffectService.tick_battle_turn!(battle_enemy)
      battle_enemy.save!
      messages << enemy_message("#{prefix}#{enemy_approach_message}#{mob_name}の#{enemy_attack_name(sword_skill)}！#{enemy_skill_hit_text(sword_skill)}#{guard_message}#{enemy_damage}ダメージを受けた！")
    end

    player.save!
    if battle.alive_enemies.reload.empty?
      player.clear_sword_skill_cooldowns!
      player.clear_potion_healing!
      player.save!
      battle.destroy!
      messages << "敵はいなくなった。"
    end

    Result.new(status: :ok, message: messages.join)
  end

  def self.resolve_throw_item!(battle:, player:, item_id:, mob_part_id:, target_enemy_id:)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    blocked_result = resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    return blocked_result if blocked_result

    item = player.items.find_by(id: item_id)
    return Result.new(status: :error, message: "投擲できるアイテムがありません。") unless item&.throwable? && item.quantity.to_i.positive?

    target = target_enemies_for(battle, target_enemy_id, nil, false).first
    return Result.new(status: :error, message: "攻撃対象がいません。") unless target
    return Result.new(status: :error, message: "近距離では投擲できません。") if target.distance_key == "near"

    result = resolve_throw_hit!(
      player: player,
      item: item,
      battle_enemy: target,
      mob_part_id: mob_part_id
    )
    consume_throwable_item!(item)
    consume_player_ambush_opening!(battle)

    if battle.alive_enemies.reload.empty?
      return finish_battle_victory!(player, battle, nil, "投擲", result, 0, false, nil)
    end

    BuffEffectService.tick_battle_turn!(player)
    player.save!
    battle.save!
    enemy_result = apply_enemy_attack!(player, battle, except_enemy_ids: [target.id])
    return enemy_result if enemy_result.status == :defeated

    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    Result.new(status: :ok, message: "#{turn_messages.join}#{item.name}を投擲した！#{result}！#{enemy_result.message}")
  end

  def self.resolve_backstep!(player, battle, target_enemy_id: nil)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    blocked_result = resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    return blocked_result if blocked_result
    return Result.new(status: :error, message: "囲まれていて距離を取れません。") if encircled?(battle)

    target = target_enemies_for(battle, target_enemy_id, nil, false).first
    return Result.new(status: :error, message: "距離を取る対象がいません。") unless target
    return Result.new(status: :error, message: "#{target.display_name}とは既に遠距離です。") if target.distance_key == "far"

    BuffEffectService.tick_battle_turn!(player)
    player.save!

    if backstep_success?(player, battle, target)
      before = target.distance_label
      target.increase_distance!
      mark_backstep_action_skip!(target)
      consume_player_ambush_opening!(battle)
      enemy_result = apply_enemy_attack!(player, battle)
      return enemy_result if enemy_result.status == :defeated

      tick_sword_skill_cooldowns_for_turn!(player, battle)
      player.save!
      Result.new(status: :ok, message: "#{turn_messages.join}バックステップ！#{target.display_name}との距離を#{before}から#{target.distance_label}へ離した。#{enemy_result.message}")
    else
      consume_player_ambush_opening!(battle)
      enemy_result = apply_enemy_attack!(player, battle)
      return enemy_result if enemy_result.status == :defeated

      tick_sword_skill_cooldowns_for_turn!(player, battle)
      player.save!
      Result.new(status: :ok, message: "#{turn_messages.join}バックステップに失敗した！#{enemy_result.message}")
    end
  end

  def self.resolve_evasive_action!(player, battle)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    blocked_result = resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    return blocked_result if blocked_result

    BuffEffectService.tick_battle_turn!(player)
    consume_player_ambush_opening!(battle)
    player.save!
    enemy_result = apply_enemy_attack!(player, battle, prefix: "回避行動中、", evasion_focus: true)
    return enemy_result if enemy_result.status == :defeated

    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    Result.new(status: :ok, message: "#{turn_messages.join}回避行動を取った。#{enemy_result.message}")
  end

  def self.resolve_defense!(player, battle)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    blocked_result = resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    return blocked_result if blocked_result

    shield = player.equipped_shield
    return Result.new(status: :error, message: "盾を装備していないため、防御できません。") unless shield

    BuffEffectService.tick_battle_turn!(player)
    consume_player_ambush_opening!(battle)
    player.save!

    enemy_result = apply_enemy_attack!(player, battle, prefix: "防御中、", allow_evasion: false, shield_guard: true)
    return enemy_result if enemy_result.status == :defeated

    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    Result.new(status: :ok, message: "#{turn_messages.join}防御姿勢を取った。#{enemy_result.message}")
  end

  def self.resolve_parry!(player, battle)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    alive_enemies = battle.alive_enemies.reload.to_a
    return Result.new(status: :error, message: "パリィは敵と1対1の時だけ狙えます。") unless alive_enemies.one?

    blocked_result = resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    return blocked_result if blocked_result

    parry_tool = parry_tool_for(player)
    return Result.new(status: :error, message: "盾または武器を装備していないため、パリィできません。") unless parry_tool

    BuffEffectService.tick_battle_turn!(player)
    consume_player_ambush_opening!(battle)
    player.save!

    enemy_result = apply_enemy_attack!(
      player,
      battle,
      prefix: "パリィを狙い、",
      allow_evasion: false,
      parry_attempt: true,
      parry_tool: parry_tool
    )
    return enemy_result if enemy_result.status == :defeated

    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    Result.new(status: :ok, message: "#{turn_messages.join}パリィを狙った。#{enemy_result.message}")
  end

  def self.resolve_player_action_block!(player, battle)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    ensure_battle_enemies!(battle)
    turn_messages = apply_battle_turn_start_effects!(player, battle)
    return handle_player_defeat!(player, battle, "#{turn_messages.join}あなたは倒れた……。") if player.hp.to_i <= 0

    blocked_message = StatusEffectService.action_blocked_message!(player)
    return nil unless blocked_message

    BuffEffectService.tick_battle_turn!(player)
    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    enemy_result = apply_enemy_attack!(player, battle)
    return enemy_result if enemy_result.status == :defeated

    Result.new(status: :ok, message: "#{turn_messages.join}#{blocked_message}#{enemy_result.message}")
  end

  def self.resolve_player_action_block_after_turn_start!(player, battle, turn_messages)
    blocked_message = StatusEffectService.action_blocked_message!(player)
    return nil unless blocked_message

    BuffEffectService.tick_battle_turn!(player)
    tick_sword_skill_cooldowns_for_turn!(player, battle)
    player.save!
    enemy_result = apply_enemy_attack!(player, battle)
    return enemy_result if enemy_result.status == :defeated

    Result.new(status: :ok, message: "#{turn_messages.join}#{blocked_message}#{enemy_result.message}")
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

    enemy_level = battle.mob.effective_level
    enemy_max_hp = battle.mob.hp_for_level(enemy_level)
    battle.battle_enemies.create!(
      FieldService.battle_enemy_attributes(
        mob: battle.mob,
        enemy_hp: battle.enemy_hp || enemy_max_hp,
        enemy_max_hp: enemy_max_hp,
        enemy_level: enemy_level,
        position: 1,
        distance: FieldService.initial_battle_distance(battle.initiative_key)
      )
    )
    battle.alive_enemies.to_a
  end

  def self.target_enemies_for(battle, target_enemy_id, group_start, area, target_enemy_ids = nil, max_targets: 4)
    alive = battle.alive_enemies.to_a
    if area
      limit = [max_targets.to_i, 1].max
      selected_ids = Array(target_enemy_ids).flat_map { |ids| ids.to_s.split(",") }.map(&:to_i).reject(&:zero?)
      if selected_ids.any?
        return alive.select { |enemy| selected_ids.include?(enemy.id) }.first(limit)
      end

      start = group_start.to_i
      start = alive.first&.position.to_i if start <= 0
      alive.select { |enemy| enemy.position >= start && enemy.position < start + limit }.first(limit)
    elsif target_enemy_id.present?
      alive.select { |enemy| enemy.id == target_enemy_id.to_i }
    else
      alive.first ? [alive.first] : []
    end
  end

  def self.player_attack_reaches?(weapon, battle_enemy, sword_skill: false)
    distance_reachable?(battle_enemy, weapon_reach_rank(weapon))
  end

  def self.player_attack_can_close_and_reach?(weapon, battle_enemy, sword_skill: false)
    distance_rank_after_player_approach(battle_enemy) <= weapon_reach_rank(weapon)
  end

  def self.enemy_attack_reaches?(battle_enemy, sword_skill: false)
    distance_reachable?(battle_enemy, weapon_reach_rank(battle_enemy.mob.equipped_weapon))
  end

  def self.enemy_attack_can_close_and_reach?(battle_enemy, sword_skill: false)
    distance_rank_after_standard_approach(battle_enemy) <= weapon_reach_rank(battle_enemy.mob.equipped_weapon)
  end

  def self.distance_reachable?(battle_enemy, reach_rank)
    battle_enemy.distance_rank <= reach_rank
  end

  def self.distance_rank_after_standard_approach(battle_enemy)
    [battle_enemy.distance_rank - 1, 0].max
  end

  def self.distance_rank_after_player_approach(battle_enemy)
    player_ambush_opening?(battle_enemy.battle) ? 0 : distance_rank_after_standard_approach(battle_enemy)
  end

  def self.weapon_reach_rank(weapon)
    return 0 unless weapon

    weapon_type = weapon.weapon_type.to_s
    return 2 if FAR_REACH_WEAPON_TYPES.any? { |type| weapon_type.include?(type) }
    return 1 if MIDDLE_REACH_WEAPON_TYPES.any? { |type| weapon_type.include?(type) }

    0
  end

  def self.close_distance!(battle_enemy)
    battle_enemy.decrease_distance! unless battle_enemy.distance_key == "near"
  end

  def self.approach_for_player_attack!(weapon, battle_enemy, sword_skill: false)
    return if player_attack_reaches?(weapon, battle_enemy, sword_skill: sword_skill)

    before = battle_enemy.distance_label
    if player_ambush_opening?(battle_enemy.battle)
      battle_enemy.update!(distance: "near")
    else
      close_distance!(battle_enemy)
    end
    "#{battle_enemy.display_name}へ接近した（#{before}→#{battle_enemy.distance_label}）。"
  end

  def self.player_ambush_opening?(battle)
    battle&.player_ambush? && battle.ambush?
  end

  def self.consume_player_ambush_opening!(battle)
    battle.update!(ambush: false) if battle&.ambush?
  end

  def self.mark_backstep_action_skip!(battle_enemy)
    BuffEffectService.apply_battle_effect!(battle_enemy, BACKSTEP_ACTION_SKIP_KEY, {}, turns: 1)
    battle_enemy.save!
  end

  def self.enemy_action_skipped_by_backstep?(battle_enemy)
    data = BuffEffectService.battle_effects(battle_enemy)
    return false unless data.delete(BACKSTEP_ACTION_SKIP_KEY)

    battle_enemy.battle_effects = data.to_json
    battle_enemy.save!
    true
  end

  def self.mark_parry_action_skip!(battle_enemy)
    BuffEffectService.apply_battle_effect!(battle_enemy, PARRY_ACTION_SKIP_KEY, {}, turns: 2)
    battle_enemy.save!
  end

  def self.enemy_action_skipped_by_parry?(battle_enemy)
    data = BuffEffectService.battle_effects(battle_enemy)
    return false unless data.delete(PARRY_ACTION_SKIP_KEY)

    battle_enemy.battle_effects = data.to_json
    battle_enemy.save!
    true
  end

  def self.encircled?(battle)
    battle.alive_enemies.to_a.count { |battle_enemy| battle_enemy.distance_key == "near" } >= 3
  end

  def self.backstep_success?(player, battle, target)
    enemy_agility = battle.alive_enemies.map { |battle_enemy| mob_effective_agility(battle_enemy) }.max.to_i
    agility_gap = player.effective_agility - enemy_agility
    enemy_count_penalty = [battle.alive_enemies.size - 1, 0].max * 8
    chance = [[70 + agility_gap * 5 - enemy_count_penalty, 25].max, 95].min
    rand(100) < chance
  end

  def self.resolve_hit!(player:, weapon:, battle_enemy:, mob_part_id:, damage_multiplier:, attack_attribute:, sword_skill: false, skill_key: nil)
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
    unless guard_result[:guarded] || player_attack_hit?(player, battle_enemy, actual_part, weapon: weapon, sword_skill: sword_skill, skill_key: skill_key)
      return "#{battle_enemy.mob.name}: #{guard_result[:message]}躱された！"
    end

    raw_hit_damage = calculate_player_damage(player, weapon, battle_enemy, actual_part, attack_attribute) * damage_multiplier / 100.0
    raw_hit_damage *= 1.0 + SkillModEffects.normal_damage_percent(player, weapon, battle_enemy) / 100.0 unless sword_skill
    varied_damage = apply_player_damage_variance(raw_hit_damage)
    part_damage = calculate_part_damage(varied_damage, weapon, actual_part)
    part_damage = (part_damage * (1.0 + SkillModEffects.part_damage_percent(player, weapon) / 100.0)).ceil
    if SkillModEffects.true_straight_triggers?(player, weapon, actual_part, sword_skill)
      part_damage += [part_damage / 2, 1].max
    end
    critical = StatusEffectService.sleeping_critical!(battle_enemy) || critical_hit?(player, weapon, battle_enemy, actual_part, part_damage, sword_skill: sword_skill, skill_key: skill_key)
    hit_damage = critical ? varied_damage * 2 : varied_damage
    battle_enemy.enemy_hp = [battle_enemy.enemy_hp.to_i - hit_damage, 0].max
    break_message = apply_part_damage!(player, battle_enemy, actual_part, part_damage)
    SkillModEffects.mark_linked_break!(player, weapon) if break_message.present?
    battle_enemy.save!
    record_evolution_progress!(weapon, critical: critical, defeated: battle_enemy.enemy_hp <= 0)

    critical_message = critical ? "クリティカル！" : ""
    defeated_message = battle_enemy.enemy_hp <= 0 ? " #{battle_enemy.mob.name}を倒した！" : ""
    "#{battle_enemy.mob.name}: #{guard_result[:message]}#{critical_message}#{actual_part.name}へ#{hit_damage}ダメージ#{break_message}#{defeated_message}"
  end

  def self.record_evolution_progress!(weapon, critical:, defeated:)
    return unless weapon&.evolvable_origin?

    weapon.increment!(:critical_hit_count) if critical
    weapon.increment!(:kill_count) if defeated
  end

  def self.resolve_throw_hit!(player:, item:, battle_enemy:, mob_part_id:)
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
    unless guard_result[:guarded] || player_throw_hit?(player, battle_enemy)
      return "#{battle_enemy.mob.name}: #{guard_result[:message]}躱された！"
    end

    raw_hit_damage = calculate_throw_damage(player, item, battle_enemy, actual_part)
    varied_damage = apply_player_damage_variance(raw_hit_damage)
    part_damage = calculate_part_damage(varied_damage, nil, actual_part)
    critical = StatusEffectService.sleeping_critical!(battle_enemy)
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
    damage_multiplier * reduction
  end

def self.calculate_player_damage(player, weapon, battle_enemy, part, attack_attribute)
  weapon_power = weapon&.effective_attack_power.to_f
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
  [base_damage * part.damage_multiplier.to_i / 100.0, 1.0].max
end

def self.calculate_throw_damage(player, item, battle_enemy, part)
  base_power = player.effective_strength.to_f + item.throw_attack_power.to_f
  base_power *= throw_distance_multiplier(battle_enemy)
  base_power *= attribute_multiplier(nil, battle_enemy.mob, part, item.throw_attack_attribute)
  defense_rate = 100.0 / (100 + [battle_enemy.effective_durability, 0].max)
  base_damage = base_power * defense_rate
  base_damage *= StatusEffectService.damage_dealt_multiplier(player)
  base_damage *= StatusEffectService.damage_taken_multiplier(battle_enemy)
  base_damage *= BuffEffectService.defense_damage_taken_multiplier(battle_enemy)
  [base_damage * part.damage_multiplier.to_i / 100.0, 1.0].max
end

def self.throw_distance_multiplier(battle_enemy)
  battle_enemy.distance_key == "far" ? 0.55 : 0.8
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
  cap = SkillModEffects.proficiency_attack_cap(player, weapon)
  1.0 + (skill&.proficiency.to_i / 1000.0 * cap)
end

  def self.player_attack_hit?(player, battle_enemy, part, weapon: nil, sword_skill: false, skill_key: nil)
    return true if enemy_sword_skill_stiffness?(battle_enemy)

    player_agility = (player.effective_agility * BuffEffectService.agility_multiplier(player)).round
    agility_gap = player_agility - mob_effective_agility(battle_enemy)
    part_modifier = part.weakness? ? -10 : 0
    ambush_bonus = player_ambush_opening?(battle_enemy.battle) ? 15 : 0

    return true if BuffEffectService.sure_hit?(player)

    chance = 85 + (agility_gap * 3) + part_modifier + ambush_bonus
    chance += BuffEffectService.accuracy_modifier(player)
    chance -= BuffEffectService.accuracy_modifier(battle_enemy)
    chance += weapon.sword_skill_accuracy_bonus if sword_skill && weapon
    chance += SkillModEffects.hit_bonus(player, weapon, battle_enemy, part, sword_skill: sword_skill) if weapon
    chance += SkillModEffects.sword_skill_accuracy_bonus(player, weapon, skill_key) if sword_skill && weapon
    chance = chance.clamp(55, sword_skill ? 100 : 98)

    rand(100) < chance
  end

  def self.player_throw_hit?(player, battle_enemy)
    player_agility = (player.effective_agility * BuffEffectService.agility_multiplier(player)).round
    agility_gap = player_agility - mob_effective_agility(battle_enemy)
    distance_penalty = battle_enemy.distance_key == "far" ? 30 : 15
    chance = [[45 + (agility_gap * 4) - distance_penalty + BuffEffectService.accuracy_modifier(player), 5].max, 70].min
    rand(100) < chance
  end

  def self.durability_loss_for(weapon, base_cost, attack_attribute)
    return base_cost.to_i unless weapon
    return 0 if base_cost.to_i.positive? && SkillModEffects.normal_durability_save?(weapon.player, weapon)
    return base_cost.to_i if weapon.matches_attack_attribute?(attack_attribute)

    [base_cost.to_i * 2, base_cost.to_i + 1].max
  end

  def self.effective_sword_skill_cooldown(player, weapon, base_cooldown)
    cooldown = base_cooldown.to_i
    return cooldown unless cooldown.positive?

    [cooldown - SkillModEffects.cooldown_reduction(player, weapon, cooldown), 1].max
  end

  def self.effective_sword_skill_durability_cost(player, weapon, skill_key, base_cost, base_cooldown)
    cost = base_cost.to_i
    cost -= SkillModEffects.sword_skill_durability_reduction(player, weapon, skill_key)
    cost += SkillModEffects.additional_sword_skill_durability_cost(player, weapon, base_cooldown)
    [cost, 1].max
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
    StatusEffectService.clear_all!(player)
    player.clear_sword_skill_cooldowns!
    player.clear_potion_healing!
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
    potion_heal = player.tick_potion_healing!
    messages << "ポーションの回復効果。HPが#{potion_heal}回復した。" if potion_heal.to_i.positive?

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
      StatusEffectService.accumulate!(player, status, varied_status_attack_amount(amount))
    end
  end

  def self.varied_status_attack_amount(amount)
    base_amount = amount.to_f
    return 0 if base_amount <= 0

    (base_amount * rand(STATUS_ATTACK_VARIANCE_RANGE) / 100.0).round(2)
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
    player.clear_sword_skill_cooldowns!
    player.clear_potion_healing!
    player.save!
    battle.destroy!

    broken_message = destroy_weapon_if_broken!(weapon)
    victory_message = defeated_enemies.many? ? "敵を全て倒した！" : ""
    reward_message = "#{victory_message}#{col_reward}刻銭獲得！#{exp_message}#{boss_reward_message}#{dropped_item_message}#{broken_part_drop_message}#{dropped_weapon_message}"
    Result.new(status: :ok, message: "#{label}！#{damage_message}！[reward]#{reward_message}[/reward]#{broken_message}#{skill_message}")
  end

  def self.hit_message(index, hits, message)
    hits > 1 ? "#{index + 1}撃目 #{message}" : message
  end

  def self.apply_player_damage_variance(damage)
    [(damage.to_f * rand(75..100) / 100.0).floor, 1].max
  end

  def self.calculate_part_damage(hp_damage, weapon, part)
    weapon_break_power = weapon&.effective_part_break_power || 100
    part_modifier = part.weakness? ? 0.8 : 1.0
    [(hp_damage.to_i * 0.35 * weapon_break_power / 100.0 * part_modifier).ceil, 1].max
  end

  def self.critical_hit?(player, weapon, battle_enemy, part, damage, sword_skill: false, skill_key: nil)
    return false unless weapon

    agility_bonus = (player.effective_agility - mob_effective_agility(battle_enemy)) / 5
    stiffness_bonus = enemy_sword_skill_stiffness?(battle_enemy) ? ENEMY_SWORD_SKILL_STIFFNESS_CRITICAL_BONUS : 0
    accuracy_bonus = sword_skill ? weapon.accuracy_level.to_i : 0
    part_bonus = if part_broken?(battle_enemy, part)
                   15
                 elsif part.weakness? && part_would_break?(battle_enemy, part, damage)
                   10
                 else
                   0
                 end
    counter_reading_bonus = sword_skill ? SkillModEffects.consume_counter_reading_bonus(player) : 0
    chance_cap = (enemy_sword_skill_stiffness?(battle_enemy) ? 75 : 30) + accuracy_bonus + counter_reading_bonus
    base_rate = sword_skill ? weapon.sword_skill_critical_rate : weapon.effective_critical_rate
    base_rate += counter_reading_bonus
    chance = [ [ base_rate + agility_bonus + stiffness_bonus + part_bonus, 1 ].max, chance_cap ].min
    rand(100) < chance
  end

  def self.part_would_break?(battle_enemy, part, damage)
    state = battle_part_states(battle_enemy)[part.id.to_s] || default_part_state(part)
    return false if state["broken"]

    state["durability"].to_i <= damage.to_i
  end

  def self.resolve_guarded_part(player, battle_enemy, parts, target_part)
    return { part: target_part, message: "", blocked: false, guarded: false } unless enemy_guard_success?(player, battle_enemy, target_part)

    if battle_enemy.mob.equipped_weapon && target_part.weakness? && !part_broken?(battle_enemy, target_part)
      return { part: target_part, message: "#{battle_enemy.mob.equipped_weapon.name}で弾かれた！", blocked: true, guarded: true }
    end

    guard_part = guard_part_for(battle_enemy, parts, target_part)
    guard_part ? { part: guard_part, message: "#{guard_part.name}で防がれた！", blocked: false, guarded: true } : { part: target_part, message: "", blocked: false, guarded: false }
  end

  def self.weapon_knockback_result?(message)
    message.to_s.include?("で弾かれた！")
  end

  def self.resolve_enemy_attack_parry!(player, battle, battle_enemy, sword_skill, parry_tool, prefix, enemy_approach_message)
    mob_name = battle_enemy.mob.name
    tool_name = parry_tool_name(parry_tool)
    if parry_success?(player, battle_enemy, parry_tool)
      apply_parry_durability_loss!(parry_tool, battle_enemy, sword_skill, success: true)
      start_enemy_sword_skill_cooldown!(battle_enemy, sword_skill) if sword_skill
      mark_enemy_stagger!(battle_enemy)
      mark_parry_action_skip!(battle_enemy)
      SkillModEffects.mark_counter_reading!(player, parry_tool)
      BuffEffectService.tick_battle_turn!(battle_enemy)
      battle_enemy.save!
      player.save!
      broken_message = parry_tool.is_a?(Weapon) ? destroy_weapon_if_broken!(parry_tool) : ""

      return Result.new(
        status: :ok,
        message: enemy_message("#{prefix}#{enemy_approach_message}#{mob_name}の#{enemy_attack_name(sword_skill)}を#{tool_name}でパリィした！#{mob_name}は体勢を崩した！#{broken_message}")
      )
    end

    apply_parry_durability_loss!(parry_tool, battle_enemy, sword_skill, success: false)
    enemy_damage = enemy_attack_damage(player, battle_enemy, sword_skill, forced_critical: true)
    player.hp = player.hp.to_i - enemy_damage
    apply_mob_status_attacks!(player, battle_enemy)
    broken_message = parry_tool.is_a?(Weapon) ? destroy_weapon_if_broken!(parry_tool) : ""

    if player.hp <= 0
      return handle_player_defeat!(
        player,
        battle,
        "#{enemy_message("#{prefix}#{enemy_approach_message}パリィに失敗した！#{mob_name}の#{enemy_attack_name(sword_skill)}！クリティカル！#{enemy_damage}ダメージを受けた！#{broken_message}")}あなたは倒れた……。"
      )
    end

    BuffEffectService.tick_battle_turn!(battle_enemy)
    battle_enemy.save!
    player.save!
    Result.new(
      status: :ok,
      message: enemy_message("#{prefix}#{enemy_approach_message}パリィに失敗した！#{mob_name}の#{enemy_attack_name(sword_skill)}！クリティカル！#{enemy_damage}ダメージを受けた！#{broken_message}")
    )
  end

  def self.parry_tool_for(player)
    shield = player.equipped_shield
    return shield if shield

    weapon = combat_weapon_for(player)
    weapon unless weapon&.broken?
  end

  def self.parry_tool_name(parry_tool)
    parry_tool.respond_to?(:display_name) ? parry_tool.display_name : parry_tool.name
  end

  def self.parry_success?(player, battle_enemy, parry_tool)
    strength_gap = player.effective_strength - mob_effective_strength_for_parry(battle_enemy)
    chance = (parry_base_rate(parry_tool) + strength_gap * 4 + SkillModEffects.parry_bonus(player, parry_tool)).clamp(10, 90)
    rand(100) < chance
  end

  def self.parry_base_rate(parry_tool)
    return PARRY_BASE_RATES.fetch("shield") if parry_tool.is_a?(Armor)

    PARRY_BASE_RATES.fetch(parry_tool.weapon_type, 30)
  end

  def self.mob_effective_strength_for_parry(battle_enemy)
    mob_effective_atk(battle_enemy)
  end

  def self.apply_parry_durability_loss!(parry_tool, battle_enemy, sword_skill, success:)
    loss = parry_durability_loss(parry_tool, battle_enemy, sword_skill, success: success)
    parry_tool.apply_durability_loss!(loss)
    parry_tool.save! if parry_tool.is_a?(Weapon)
  end

  def self.parry_durability_loss(parry_tool, battle_enemy, sword_skill, success:)
    pressure = enemy_attack_power(battle_enemy, sword_skill)
    sturdiness = parry_tool_sturdiness(parry_tool)
    base_loss = [(pressure * 12.0 / [sturdiness, 10].max).ceil, 1].max
    loss = success ? base_loss : [base_loss * 3, base_loss + 2].max
    return loss if success

    (loss * SkillModEffects.failed_parry_durability_multiplier(parry_tool.player, parry_tool)).ceil
  end

  def self.parry_tool_sturdiness(parry_tool)
    if parry_tool.is_a?(Armor)
      parry_tool.max_durability.to_i + parry_tool.defense.to_i * 5
    else
      parry_tool.effective_max_durability + parry_tool.durability_level.to_i * 10 + parry_tool.part_break_power.to_i
    end
  end

  def self.enemy_sword_skill_weapon_guarded?(player, battle_enemy, sword_skill)
    weapon = combat_weapon_for(player)
    return false unless sword_skill && weapon && !weapon.broken?

    agility_gap = player.effective_agility - mob_effective_agility(battle_enemy)
    chance = (25 + (agility_gap * 4) + weapon.effective_critical_rate / 2).clamp(10, 65)
    rand(100) < chance
  end

  def self.enemy_guard_success?(player, battle_enemy, target_part)
    base_chance = target_part.weakness? || part_broken?(battle_enemy, target_part) ? 65 : 20
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
      drop = MobDropCatalog.roll_defeat_drop(battle_enemy.mob, enemy_level: battle_enemy.effective_level)
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

  def self.enemy_sword_skill_for(battle_enemy)
    return unless battle_enemy.mob.equipped_weapon

    candidates = enemy_sword_skills_for(battle_enemy)
    return if candidates.empty?
    return candidates.sample if battle_enemy.mob.boss?
    return unless rand(100) < ENEMY_SWORD_SKILL_RATE

    candidates.sample
  end

  def self.enemy_sword_skills_for(battle_enemy)
    weapon = battle_enemy.mob.equipped_weapon
    return [] unless weapon
    return [] if enemy_weapon_arm_broken?(battle_enemy)

    configured_keys = battle_enemy.mob.enemy_sword_skill_key_list
    return [] if configured_keys.empty?

    skills = SkillCatalog.sword_skills(weapon.weapon_type)
    skills.select do |skill|
      configured_keys.include?(skill.key.to_s) && !enemy_sword_skill_on_cooldown?(battle_enemy, skill.key)
    end
  end

  def self.enemy_sword_skill_on_cooldown?(battle_enemy, skill_key)
    BuffEffectService.battle_effects(battle_enemy).key?(enemy_sword_skill_cooldown_key(skill_key))
  end

  def self.enemy_weapon_arm_broken?(battle_enemy)
    battle_enemy.mob.mob_parts.any? do |part|
      part.break_effect == "strength_down" &&
        part.name.match?(/手|腕|前脚/) &&
        part_broken?(battle_enemy, part)
    end
  end

  def self.enemy_sword_skill_stiffness?(battle_enemy)
    BuffEffectService.battle_effects(battle_enemy).key?(ENEMY_SWORD_SKILL_STIFFNESS_KEY)
  end

  def self.mark_enemy_sword_skill_stiffness!(battle_enemy, sword_skill)
    return unless sword_skill

    mark_enemy_stagger!(battle_enemy)
  end

  def self.mark_enemy_stagger!(battle_enemy)
    BuffEffectService.apply_battle_effect!(
      battle_enemy,
      ENEMY_SWORD_SKILL_STIFFNESS_KEY,
      { "enemy_sword_skill_stiffness" => true },
      turns: 2
    )
  end

  def self.clear_enemy_sword_skill_stiffness_for!(battle_enemies)
    Array(battle_enemies).each do |battle_enemy|
      data = BuffEffectService.battle_effects(battle_enemy)
      next unless data.delete(ENEMY_SWORD_SKILL_STIFFNESS_KEY)

      battle_enemy.battle_effects = data.to_json
      battle_enemy.save!
    end
  end

  def self.start_enemy_sword_skill_cooldown!(battle_enemy, skill)
    return unless skill&.cooldown.to_i.positive?

    BuffEffectService.apply_battle_effect!(
      battle_enemy,
      enemy_sword_skill_cooldown_key(skill.key),
      {},
      turns: skill.cooldown.to_i + 1
    )
  end

  def self.enemy_sword_skill_cooldown_key(skill_key)
    "enemy_sword_skill:#{skill_key}"
  end

  def self.enemy_attack_name(sword_skill)
    sword_skill ? sword_skill.name : "攻撃"
  end

  def self.enemy_skill_hit_text(sword_skill)
    return "" unless sword_skill&.hits.to_i > 1

    "#{sword_skill.hits.to_i}ヒット "
  end

  def self.enemy_attack_damage(player, battle_enemy, sword_skill, shield_guard: false, forced_critical: false)
    start_enemy_sword_skill_cooldown!(battle_enemy, sword_skill) if sword_skill

    hit_count = sword_skill ? [sword_skill.hits.to_i, 1].max : 1
    Array.new(hit_count).sum do
      raw_damage = (enemy_attack_power(battle_enemy, sword_skill) * rand(85..100) / 100.0).round
      apply_enemy_damage_mitigation(player, battle_enemy, raw_damage, shield_guard: shield_guard, forced_critical: forced_critical)
    end
  end

  def self.enemy_attack_power(battle_enemy, sword_skill)
    base_power = mob_effective_atk(battle_enemy)
    if sword_skill
      base_power += battle_enemy.mob.equipped_weapon&.effective_attack_power.to_f
      base_power *= sword_skill.damage_multiplier.to_i / 100.0
    end

    [base_power, 1].max
  end

  def self.apply_enemy_damage_mitigation(player, battle_enemy, raw_damage, shield_guard: false, forced_critical: false)
    defense_cut = player.damage_cut.to_i
    defense_cut += player.shield_defense if shield_guard

    if shield_guard
      player.equipped_shield&.apply_durability_loss!(1)
    else
      player.equipped_body_armors.each { |armor| armor.apply_durability_loss!(1) }
    end

    defense_rate = 100.0 / (100 + [defense_cut, 0].max * 10)
    enemy_damage = [(raw_damage * defense_rate).ceil, 1].max
    enemy_damage = (enemy_damage * StatusEffectService.damage_dealt_multiplier(battle_enemy)).ceil
    enemy_damage = (enemy_damage * StatusEffectService.damage_taken_multiplier(player)).ceil
    enemy_damage = (enemy_damage * BuffEffectService.defense_damage_taken_multiplier(player)).ceil
    enemy_damage *= 2 if forced_critical || StatusEffectService.sleeping_critical!(player)
    enemy_damage = (enemy_damage * SkillModEffects.enemy_damage_taken_multiplier(player)).ceil
    enemy_damage
  end

  def self.mob_effective_agility(battle_enemy)
    penalty = broken_parts_with_effect(battle_enemy, "agility_down").count * 0.35
    [(battle_enemy.effective_agility * (1.0 - penalty)).ceil, 1].max
  end

  def self.broken_parts_with_effect(battle_enemy, effect)
    battle_enemy.mob.mob_parts.select { |part| part.break_effect == effect && part_broken?(battle_enemy, part) }
  end

  def self.enemy_attack_evaded?(player, battle_enemy, focused: false)
    player_agility = (player.effective_agility * BuffEffectService.agility_multiplier(player)).round
    agility_gap = player_agility - mob_effective_agility(battle_enemy)
    weight_penalty = player.overweight? ? (player.overweight_amount * 2).ceil : 0
    base = focused ? 45 : 10
    floor = focused ? 20 : 5
    cap = focused ? 90 : 75
    chance = [[base + (agility_gap * 5) - weight_penalty, floor].max, cap].min
    rand(100) < chance
  end

  def self.enemy_flees?(battle_enemy)
    rate = battle_enemy.mob.effective_flee_rate
    rate.positive? && rand(100) < rate
  end

  def self.consume_throwable_item!(item)
    item.quantity = item.quantity.to_i - 1
    item.quantity.positive? ? item.save! : item.destroy!
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
    message += " [levelup]レベル#{player.level}に上昇！振り分けポイント +#{level_gain * 3}[/levelup]" if level_gain.positive?
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

# キル時のexp加算(kill_exp/sword_skill_kill_bonus)を主軸に保つため、
# 毎ヒットで加算する分はCSV上のuse_expの一部（1/3）に抑える。
PER_HIT_PROFICIENCY_EXP_RATIO = 1.0 / 3

def self.gain_weapon_use_exp!(player, weapon)
  return "" unless weapon

  growth = SkillGrowthCatalog.find(weapon_skill_name(weapon))
  per_hit_exp = (growth.use_exp * PER_HIT_PROFICIENCY_EXP_RATIO).ceil
  gain_weapon_skill!(player, weapon, per_hit_exp)
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
      " #{skill_name}の熟練度が #{learned_skill.required_proficiency} に到達した。新しい錬技「#{name}」を習得した！"
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

  def self.combat_weapon_for(player)
    weapon = player&.equipped_weapon
    return nil unless weapon&.player_id == player.id
    return nil unless weapon.equipped?

    weapon
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
      enhance_limit: weapon.enhance_limit,
      enhancement_difficulty: weapon.enhancement_difficulty,
      equipped: false,
      origin: mob.boss_type == "normal" ? "mob_drop" : "boss_drop"
    )

    " #{mob.name}が#{weapon.name}を落とした！"
  end

  def self.record_normal_attack_use!(player, weapon)
    player.increment_skill_counter!(SkillUnlockService.weapon_attack_counter_key(weapon_skill_name(weapon)))
  end

  def self.finish_player_cooldown_turn!(player, battle, skill_key:, cooldown:, sword_skill:)
    return if battle.destroyed?

    tick_sword_skill_cooldowns_for_turn!(player, battle, used_sword_skill: sword_skill)
    player.start_sword_skill_lockout!(skill_key, cooldown) if sword_skill
    player.save!
  end

  def self.tick_sword_skill_cooldowns_for_turn!(player, battle, used_sword_skill: false)
    return if battle.destroyed?
    return if battle.alive_enemies.reload.empty?

    player.tick_sword_skill_cooldowns!
    SkillModEffects.reduce_shortest_cooldown!(player, combat_weapon_for(player)) unless used_sword_skill
  end

  def self.destroy_weapon_if_broken!(weapon)
    return "" unless weapon
    unless weapon.lost_by_durability?
      weapon.save!
      return ""
    end

    name = weapon.name
    weapon.destroy!
    " #{name}は限界を超えて大破し、消失した。"
  end
end
