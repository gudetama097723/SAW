class BattleService
  Result = Struct.new(:status, :message, keyword_init: true)

  def self.ensure_mob_parts!(mob)
    return [] unless mob
    return mob.mob_parts.to_a if mob.mob_parts.exists?

    mob.mob_parts.create!(name: "本体", damage_multiplier: 100, weakness: true)
    mob.mob_parts.to_a
  end

  def self.resolve_player_attack!(battle:, player:, mob_part_id:, label:, damage_multiplier:, durability_cost:, skill_gain:, stiffness:, hits:, sword_skill:)
    return Result.new(status: :error, message: "戦闘中ではありません。") unless battle

    weapon = player.equipped_weapon
    return Result.new(status: :error, message: "装備中の武器がありません。") unless weapon

    parts = ensure_mob_parts!(battle.mob)
    ensure_part_states!(battle, parts)
    part = parts.find { |mob_part| mob_part.id == mob_part_id.to_i } || parts.first
    return Result.new(status: :error, message: "攻撃可能な部位がありません。") unless part

    hit_messages = []
    total_damage = 0
    damage_per_hit_multiplier = damage_multiplier / hits.to_f

    hits.times do |index|
      guard_result = resolve_guarded_part(player, battle, parts, part)

      if guard_result[:blocked]
        hit_messages << hit_message(index, hits, guard_result[:message])
      elsif player_attack_hit?(player, battle, guard_result[:part])
        actual_part = guard_result[:part]
        base_hit_damage = (calculate_player_damage(player, weapon, battle.mob, actual_part) * damage_per_hit_multiplier / 100.0).ceil
        varied_damage = apply_player_damage_variance(base_hit_damage)
        critical = critical_hit?(weapon, battle, actual_part, varied_damage)
        hit_damage = critical ? varied_damage * 2 : varied_damage
        total_damage += hit_damage
        break_message = apply_part_damage!(player, battle, actual_part, hit_damage)
        critical_message = critical ? "クリティカル！" : ""
        result_message = "#{guard_result[:message]}#{critical_message}#{actual_part.name}へ#{hit_damage}ダメージ#{break_message}"
        hit_messages << hit_message(index, hits, result_message)
      else
        hit_messages << hit_message(index, hits, "#{guard_result[:message]}ミス")
      end
    end

    weapon.apply_durability_loss!(durability_cost)
    battle.enemy_hp -= total_damage

    if battle.enemy_hp <= 0
      return finish_battle_victory!(player, battle, weapon, part, label, hit_messages.join(" / "), skill_gain, sword_skill)
    end

    skill_message = sword_skill ? gain_sword_skill!(player, skill_gain) : ""

    player.save!
    battle.save!
    broken_message = destroy_weapon_if_broken!(weapon)
    enemy_result = apply_enemy_attack!(player, battle)
    return enemy_result if enemy_result.status == :defeated

    stiffness_message = ""
    if stiffness
      stiffness_result = apply_enemy_attack!(player, battle, prefix: "ソードスキル後の硬直中、")
      return stiffness_result if stiffness_result.status == :defeated

      stiffness_message = stiffness_result.message
    end

    Result.new(
      status: :ok,
      message: "#{battle.mob.name}の#{part.name}へ#{label}！#{hit_messages.join(' / ')}！#{enemy_result.message}#{stiffness_message}#{broken_message}#{skill_message}"
    )
  end

  def self.apply_enemy_attack!(player, battle, prefix: "")
    mob_name = battle.mob.name
    if evaded_enemy_attack?(player, battle)
      player.save!
      return Result.new(status: :ok, message: "#{prefix}#{mob_name}の攻撃を回避した！")
    end

    raw_damage = rand(1..mob_effective_atk(battle))
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

      return Result.new(status: :defeated, message: "#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！あなたは倒れた……。はじまりの街へ戻された。")
    end

    player.save!
    Result.new(status: :ok, message: "#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！")
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

  def self.calculate_player_damage(player, weapon, mob, part)
    base_damage = [player.effective_strength + weapon.attack_power.to_i - mob.durability.to_i, 1].max
    [(base_damage * part.damage_multiplier.to_i / 100.0).ceil, 1].max
  end

  def self.player_attack_hit?(player, battle, part)
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    part_modifier = part.weakness? ? -20 : 0
    chance = [[80 + (agility_gap * 5) + part_modifier, 20].max, 98].min
    rand(100) < chance
  end

  def self.finish_battle_victory!(player, battle, weapon, part, label, damage_message, skill_gain, sword_skill)
    mob = battle.mob
    player.col = player.col.to_i + 10
    skill_message = sword_skill ? gain_sword_skill!(player, skill_gain) : ""

    player.save!
    dropped_weapon_message = try_drop_weapon!(player, mob)
    exp_message = gain_exp_message(player, mob)
    battle.destroy!

    broken_message = destroy_weapon_if_broken!(weapon)
    Result.new(status: :ok, message: "#{mob.name}の#{part.name}へ#{label}！#{damage_message}！10コル獲得！#{exp_message}#{dropped_weapon_message}#{broken_message}#{skill_message}")
  end

  def self.hit_message(index, hits, message)
    hits > 1 ? "#{index + 1}撃目 #{message}" : message
  end

  def self.apply_player_damage_variance(damage)
    [(damage.to_i * rand(75..100) / 100.0).ceil, 1].max
  end

  def self.critical_hit?(weapon, battle, part, damage)
    return true if part.weakness? && part_would_break?(battle, part, damage)

    rand(100) < weapon.effective_critical_rate
  end

  def self.part_would_break?(battle, part, damage)
    state = battle_part_states(battle)[part.id.to_s] || default_part_state(part)
    return false if state["broken"]

    state["durability"].to_i <= damage.to_i
  end

  def self.resolve_guarded_part(player, battle, parts, target_part)
    return { part: target_part, message: "", blocked: false } if part_broken?(battle, target_part)
    return { part: target_part, message: "", blocked: false } unless enemy_guard_success?(player, battle, target_part)

    if battle.mob.equipped_weapon && target_part.weakness?
      return { part: target_part, message: "#{battle.mob.equipped_weapon.name}で弾かれた！", blocked: true }
    end

    guard_part = guard_part_for(battle, parts, target_part)
    guard_part ? { part: guard_part, message: "#{guard_part.name}で防がれた！", blocked: false } : { part: target_part, message: "", blocked: false }
  end

  def self.enemy_guard_success?(player, battle, target_part)
    base_chance = target_part.weakness? ? 65 : 20
    base_chance += 15 if battle.mob.equipped_weapon && target_part.weakness?
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    chance = [[base_chance - (agility_gap * 6), 5].max, 90].min
    rand(100) < chance
  end

  def self.guard_part_for(battle, parts, target_part)
    candidates = parts.reject { |part| part.id == target_part.id || part_broken?(battle, part) }
    candidates.find { |part| part.name.match?(/手|腕/) } ||
      candidates.find { |part| part.name.match?(/外膜|胴|体/) } ||
      candidates.first
  end

  def self.apply_part_damage!(player, battle, part, damage)
    states = battle_part_states(battle)
    state = states[part.id.to_s] || default_part_state(part)
    return "" if state["broken"]

    state["durability"] = state["durability"].to_i - damage.to_i
    message = ""
    if state["durability"] <= 0
      state["broken"] = true
      message = " #{part.break_message}"
      message += apply_part_drop!(player, part)
    end

    states[part.id.to_s] = state
    battle.part_states = states.to_json
    message
  end

  def self.apply_part_drop!(player, part)
    return "" if part.drop_item_name.blank?
    return "" unless rand(100) < part.drop_rate.to_i

    item = ItemService.add_item!(player, part.drop_item_name, "drop")
    item.save!
    " #{part.drop_item_name}を入手した！"
  end

  def self.default_part_state(part)
    { "durability" => part.max_durability.to_i, "broken" => false }
  end

  def self.part_broken?(battle, part)
    battle_part_states(battle).dig(part.id.to_s, "broken") == true
  end

  def self.mob_effective_atk(battle)
    penalty = broken_parts_with_effect(battle, "strength_down").count * 0.35
    [(battle.mob.atk.to_i * (1.0 - penalty)).ceil, 1].max
  end

  def self.mob_effective_agility(battle)
    penalty = broken_parts_with_effect(battle, "agility_down").count * 0.35
    [(battle.mob.effective_agility * (1.0 - penalty)).ceil, 1].max
  end

  def self.broken_parts_with_effect(battle, effect)
    battle.mob.mob_parts.select { |part| part.break_effect == effect && part_broken?(battle, part) }
  end

  def self.evaded_enemy_attack?(player, battle)
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    chance = [[10 + (agility_gap * 5), 5].max, 75].min
    rand(100) < chance
  end

  def self.gain_exp_message(player, mob)
    before_level = player.level.to_i
    before_slots = player.skill_slots.to_i
    amount = adjusted_exp_reward(player, mob)
    player.gain_exp!(amount)
    message = "#{amount}経験値獲得！"
    message += " レベル#{player.level}に上昇！振り分けポイント +3" if player.level.to_i > before_level
    message += " スキルスロット +#{player.skill_slots.to_i - before_slots}" if player.skill_slots.to_i > before_slots
    message
  end

  def self.adjusted_exp_reward(player, mob)
    level_gap = mob.effective_level - player.effective_level
    multiplier = 1.0 + (level_gap * 0.15)
    multiplier = [[multiplier, 0.1].max, 2.5].min
    [(mob.exp_reward.to_i * multiplier).round, 1].max
  end

  def self.gain_sword_skill!(player, amount)
    sword_skill = player.skills.find_or_create_by!(name: "片手剣") { |skill| skill.proficiency = 0 }
    before = sword_skill.proficiency.to_i
    actual_gain = proficiency_gain(amount, before)
    sword_skill.proficiency = [before + actual_gain, 1000].min
    sword_skill.save!

    before < 100 && sword_skill.proficiency >= 100 ? " 片手剣 +#{actual_gain} バーチカルアークを習得した！" : " 片手剣 +#{actual_gain}"
  end

  def self.proficiency_gain(base_amount, current_proficiency)
    reduction = current_proficiency.to_i / 100
    [base_amount.to_i - reduction, 1].max
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
