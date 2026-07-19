class SkillModEffects
  ONE_HANDED_SWORD = "片手直剣"
  TRAJECTORY_MEMORY_KEY = "skill_mod:trajectory_memory_target"
  COUNTER_READING_KEY = "skill_mod:counter_reading"
  LINKED_BREAK_KEY = "skill_mod:linked_break"

  def self.rank(player, skill_name, mod_key)
    skill(player, skill_name)&.skill_mod_rank(mod_key).to_i
  end

  def self.one_handed_sword?(weapon)
    weapon.respond_to?(:weapon_type) && weapon.weapon_type == ONE_HANDED_SWORD
  end

  def self.weapon_skill?(weapon, skill_name)
    weapon && weapon.weapon_type == skill_name
  end

  def self.skill(player, skill_name)
    player&.skills&.find_by(name: skill_name)
  end

  def self.hit_bonus(player, weapon, battle_enemy, part, sword_skill:)
    return 0 unless one_handed_sword?(weapon)

    bonus = rank(player, ONE_HANDED_SWORD, "blade_line") * 3
    bonus += rank(player, ONE_HANDED_SWORD, "part_insight") * 5 if part&.weakness?
    bonus += rank(player, ONE_HANDED_SWORD, "many_against_one") * 4 if battle_enemy&.battle&.alive_enemies&.size.to_i > 1
    bonus += rank(player, ONE_HANDED_SWORD, "no_retreat") * 4 if low_hp?(player)
    bonus += 5 if rank(player, ONE_HANDED_SWORD, "unnamed_inheritance").positive?
    bonus += trajectory_memory_bonus(player, battle_enemy) if sword_skill
    bonus
  end

  def self.sword_skill_damage_percent(player, weapon, skill_key, hits, battle_enemy)
    return 0 unless one_handed_sword?(weapon)

    skill_level = sword_skill_level(player, weapon, skill_key)
    bonus = skill_level / 5
    bonus += rank(player, ONE_HANDED_SWORD, "combo_maintenance") * 6 if hits.to_i >= 2
    bonus += linked_break_damage_bonus(player)
    bonus += 5 if rank(player, ONE_HANDED_SWORD, "unnamed_inheritance").positive?
    bonus
  end

  def self.normal_damage_percent(player, weapon, battle_enemy)
    return 0 unless one_handed_sword?(weapon)

    bonus = 0
    bonus += rank(player, ONE_HANDED_SWORD, "follow_through") * 10 if BattleService.enemy_sword_skill_stiffness?(battle_enemy)
    bonus += 5 if rank(player, ONE_HANDED_SWORD, "unnamed_inheritance").positive?
    bonus
  end

  def self.part_damage_percent(player, weapon)
    return 0 unless one_handed_sword?(weapon)

    rank(player, ONE_HANDED_SWORD, "fracture_insight") * 8
  end

  def self.sword_skill_accuracy_bonus(player, weapon, skill_key)
    return 0 unless one_handed_sword?(weapon)

    sword_skill_level(player, weapon, skill_key) / 20 * 2
  end

  def self.sword_skill_durability_reduction(player, weapon, skill_key)
    return 0 unless one_handed_sword?(weapon)

    skill_level = sword_skill_level(player, weapon, skill_key)
    rank(player, ONE_HANDED_SWORD, "nick_control") + (skill_level / 30)
  end

  def self.cooldown_reduction(player, weapon, base_cooldown)
    return 0 unless one_handed_sword?(weapon)

    reduction = rank(player, ONE_HANDED_SWORD, "cooldown_assist")
    reduction += rank(player, ONE_HANDED_SWORD, "final_tuning") if base_cooldown.to_i >= 3
    reduction
  end

  def self.additional_sword_skill_durability_cost(player, weapon, base_cooldown)
    return 0 unless one_handed_sword?(weapon)

    base_cooldown.to_i >= 3 ? rank(player, ONE_HANDED_SWORD, "final_tuning") : 0
  end

  def self.parry_bonus(player, parry_tool)
    return 0 unless one_handed_sword?(parry_tool)

    rank(player, ONE_HANDED_SWORD, "first_reading") * 3 +
      rank(player, ONE_HANDED_SWORD, "flowing_guard") * 5 +
      (rank(player, ONE_HANDED_SWORD, "unnamed_inheritance").positive? ? 5 : 0)
  end

  def self.failed_parry_durability_multiplier(player, parry_tool)
    return 1.0 unless one_handed_sword?(parry_tool)

    [1.0 - rank(player, ONE_HANDED_SWORD, "flowing_guard") * 0.10, 0.5].max
  end

  def self.stiffness_damage_taken_multiplier(player, weapon)
    return 1.0 unless one_handed_sword?(weapon)

    case rank(player, ONE_HANDED_SWORD, "recoil_control")
    when 3 then 0.80
    when 2 then 0.86
    when 1 then 0.92
    else 1.0
    end
  end

  def self.enemy_damage_taken_multiplier(player)
    return 1.0 unless one_handed_sword?(player&.equipped_weapon)
    return 1.0 unless low_hp?(player)

    [1.0 - rank(player, ONE_HANDED_SWORD, "no_retreat") * 0.03, 0.85].max
  end

  def self.proficiency_attack_cap(player, weapon)
    return 0.15 unless one_handed_sword?(weapon)

    0.15 + rank(player, ONE_HANDED_SWORD, "veteran_sword") * 0.05
  end

  def self.normal_durability_save?(player, weapon)
    return false unless one_handed_sword?(weapon)

    chance = rank(player, ONE_HANDED_SWORD, "light_grip") * 4
    chance.positive? && rand(100) < chance
  end

  def self.true_straight_triggers?(player, weapon, part, sword_skill)
    return false unless sword_skill && one_handed_sword?(weapon)
    return false unless part&.weakness?
    return false unless rank(player, ONE_HANDED_SWORD, "true_straight").positive?

    rand(100) < 30
  end

  def self.mark_trajectory_memory!(player, battle_enemy)
    return unless rank(player, ONE_HANDED_SWORD, "trajectory_memory").positive?

    data = player.skill_counter_data
    data[TRAJECTORY_MEMORY_KEY] = battle_enemy.id
    player.skill_counters = data.to_json
  end

  def self.consume_trajectory_memory!(player)
    data = player.skill_counter_data
    data.delete(TRAJECTORY_MEMORY_KEY)
    player.skill_counters = data.to_json
  end

  def self.trajectory_memory_bonus(player, battle_enemy)
    return 0 unless battle_enemy && player.skill_counter_data[TRAJECTORY_MEMORY_KEY].to_i == battle_enemy.id

    [0, 8, 13, 18][rank(player, ONE_HANDED_SWORD, "trajectory_memory")] || 0
  end

  def self.mark_counter_reading!(player, parry_tool)
    return unless one_handed_sword?(parry_tool)
    return unless rank(player, ONE_HANDED_SWORD, "counter_reading").positive?

    data = player.skill_counter_data
    data[COUNTER_READING_KEY] = true
    player.skill_counters = data.to_json
  end

  def self.consume_counter_reading_bonus(player)
    return 0 unless player.skill_counter_data[COUNTER_READING_KEY]

    data = player.skill_counter_data
    data.delete(COUNTER_READING_KEY)
    player.skill_counters = data.to_json
    rank(player, ONE_HANDED_SWORD, "counter_reading") * 12
  end

  def self.mark_linked_break!(player, weapon)
    return unless one_handed_sword?(weapon)
    return unless rank(player, ONE_HANDED_SWORD, "linked_break").positive?

    data = player.skill_counter_data
    data[LINKED_BREAK_KEY] = true
    player.skill_counters = data.to_json
  end

  def self.linked_break_damage_bonus(player)
    return 0 unless player.skill_counter_data[LINKED_BREAK_KEY]

    rank(player, ONE_HANDED_SWORD, "linked_break") * 15
  end

  def self.consume_linked_break!(player)
    data = player.skill_counter_data
    return unless data.delete(LINKED_BREAK_KEY)

    player.skill_counters = data.to_json
  end

  def self.reduce_shortest_cooldown!(player, weapon)
    return unless one_handed_sword?(weapon)

    amount = rank(player, ONE_HANDED_SWORD, "deep_breath")
    return unless amount.positive?

    data = player.skill_counter_data
    return if data[Player::SWORD_SKILL_LOCKOUT_KEY].to_i.positive?

    cooldowns = data[Player::SWORD_SKILL_COOLDOWNS_KEY].is_a?(Hash) ? data[Player::SWORD_SKILL_COOLDOWNS_KEY] : {}
    key = cooldowns.min_by { |_skill_key, cooldown| cooldown.to_i }&.first
    return unless key

    cooldowns[key] = cooldowns[key].to_i - amount
    cooldowns.delete(key) if cooldowns[key].to_i <= 0
    cooldowns.empty? ? data.delete(Player::SWORD_SKILL_COOLDOWNS_KEY) : data[Player::SWORD_SKILL_COOLDOWNS_KEY] = cooldowns
    player.skill_counters = data.to_json
  end

  def self.escape_bonus(player, weapon)
    return 0 unless one_handed_sword?(weapon)

    rank(player, ONE_HANDED_SWORD, "many_against_one") * 4
  end

  def self.sword_skill_level(player, weapon, skill_key)
    return 1 unless weapon && skill_key.present?

    skill(player, weapon.weapon_type)&.sword_skill_level(skill_key).to_i.clamp(1, 100)
  end

  def self.low_hp?(player)
    player && player.hp.to_i <= (player.effective_max_hp * 0.30).floor
  end
end
