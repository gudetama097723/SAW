class GameController < ApplicationController
  def index
    @player = Player.first
    @battle = Battle.last
    @rest = Rest.last
    @routes = FieldService.available_routes_for(@player.location)
    if @battle
      @battle_parts = BattleService.ensure_mob_parts!(@battle.mob)
      @part_states = BattleService.ensure_part_states!(@battle, @battle_parts)
    end
  end

  def stroll
    player = Player.first

    unless player.location&.safe_area?
      redirect_to root_path, alert: "ここは安全地帯ではありません。"
      return
    end

    result = rand(100)
    next_time = (player.current_time.to_i + 10) % 1440

    if !player.found_inn && result < 30
      player.update!(found_inn: true, current_time: next_time)
      redirect_to root_path, notice: "広場の近くで宿屋を見つけた！"
    elsif !player.found_item_shop && result < 60
      player.update!(found_item_shop: true, current_time: next_time)
      redirect_to root_path, notice: "街を散策していると、道具屋を見つけた！"
    elsif !player.found_blacksmith && result < 85
      player.update!(found_blacksmith: true, current_time: next_time)
      redirect_to root_path, notice: "路地裏で鍛冶屋を見つけた！"
    else
      player.update!(current_time: next_time)
      redirect_to root_path, notice: "街を散策した。特に新しい発見はなかった。"
    end
  end

  def explore
    result = FieldService.explore!(Player.first)
    redirect_with_result(result)
  end

  def gather
    result = FieldService.gather!(Player.first)
    redirect_with_result(result)
  end

  def attack
    result = BattleService.resolve_player_attack!(
      battle: Battle.last,
      player: Player.first,
      mob_part_id: params[:mob_part_id],
      label: "通常攻撃",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false
    )
    redirect_with_result(result)
  end

  def sword_skill
    skill_key = params[:skill].presence || "vertical"
    if skill_key == "vertical_arc"
      player = Player.first
      sword_skill = player.skills.find_by(name: "片手剣")
      unless sword_skill&.proficiency.to_i >= 100
        redirect_to root_path(battle_command: "sword_skill"), alert: "バーチカルアークはまだ習得していません。"
        return
      end

      result = BattleService.resolve_player_attack!(
        battle: Battle.last,
        player: player,
        mob_part_id: params[:mob_part_id],
        label: "バーチカルアーク",
        damage_multiplier: 240,
        durability_cost: 4,
        skill_gain: 5,
        stiffness: true,
        hits: 2,
        sword_skill: true
      )
      redirect_with_result(result)
      return
    end

    result = BattleService.resolve_player_attack!(
      battle: Battle.last,
      player: Player.first,
      mob_part_id: params[:mob_part_id],
      label: "バーチカル",
      damage_multiplier: 150,
      durability_cost: 2,
      skill_gain: 3,
      stiffness: true,
      hits: 1,
      sword_skill: true
    )
    redirect_with_result(result)
  end

  def use_battle_item
    battle = Battle.last
    player = Player.first

    unless battle
      redirect_to root_path, alert: "戦闘中ではありません。"
      return
    end

    unless params[:item_name] == "ポーション"
      redirect_to root_path, alert: "そのアイテムはまだ使用できません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to root_path, alert: item_result.message
      return
    end

    enemy_result = BattleService.apply_enemy_attack!(player, battle)

    redirect_to root_path, notice: "#{item_result.message}#{enemy_result.message}"
  end

  def use_item
    player = Player.first

    if Battle.exists?
      redirect_to root_path(battle_command: "item"), alert: "戦闘中は戦闘コマンドからアイテムを使ってください。"
      return
    end

    unless params[:item_name] == "ポーション"
      redirect_to root_path(panel: "items", item_category: "healing"), alert: "そのアイテムはまだ使用できません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to root_path(panel: "items", item_category: "healing"), alert: item_result.message
      return
    end

    player.current_time = (player.current_time.to_i + 10) % 1440
    player.save!

    surprise_message = check_item_use_surprise_encounter!(player)
    return if performed?

    redirect_to root_path(panel: "items", item_category: "healing"), notice: "#{item_result.message}#{surprise_message}"
  end

  def escape
    battle = Battle.last
    player = Player.first

    unless battle
      redirect_to root_path, alert: "戦闘中ではありません。"
      return
    end

    agility_gap = player.effective_agility - battle.mob.effective_agility
    chance = [[50 + agility_gap * 10, 10].max, 95].min
    if rand(100) < chance
      battle.destroy
      redirect_to root_path, notice: "逃走に成功した。"
    else
      enemy_result = BattleService.apply_enemy_attack!(player, battle)

      redirect_to root_path, alert: "逃走に失敗した。#{enemy_result.message}"
    end
  end

  def start_rest
    player = Player.first

    if Battle.exists?
      redirect_to root_path, notice: "戦闘中は休憩できない！"
      return
    end

    danger = player.location&.danger_level || 30

    if rand(100) < danger
      redirect_to root_path, notice: "周囲に敵の気配があり、休憩できなかった。"
    else
      Rest.destroy_all
      Rest.create!(player: player)
      redirect_to root_path, notice: "休憩を開始した。"
    end
  end

  def use_rest_skill
    player = Player.first
    rest = Rest.last

    unless rest
      redirect_to root_path, notice: "休憩中ではない。"
      return
    end

    skill = player.skills.find_by(name: "昼寝")

    if skill
      heal = 10
      player.hp = [player.hp.to_i + heal, player.effective_max_hp].min
      skill.proficiency += 1
      player.current_time = (player.current_time.to_i + 10) % 1440

      player.save
      skill.save

      check_rest_encounter!(player)
      return if performed?

      redirect_to root_path, notice: "スキル《昼寝》を使用した。HPが#{heal}回復した。"
    else
      redirect_to root_path, notice: "スキル《昼寝》を習得していない。"
    end
  end

  def use_rest_item
    player = Player.first
    rest = Rest.last

    unless rest
      redirect_to root_path, alert: "休憩中ではありません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to root_path, alert: item_result.message
      return
    end

    player.current_time = (player.current_time.to_i + 10) % 1440
    player.save!

    check_rest_encounter!(player)
    return if performed?

    redirect_to root_path, notice: item_result.message
  end

  def end_rest
    Rest.destroy_all
    redirect_to root_path, notice: "休憩を終えた。"
  end

  def move
    player = Player.first
    route = Route.find(params[:route_id])

    if Battle.exists?
      redirect_to root_path, notice: "戦闘中は移動できない！"
      return
    end

    if Rest.exists?
      redirect_to root_path, notice: "休憩中は移動できない！"
      return
    end

    player.location = route.to_location
    player.current_time = (player.current_time.to_i + route.travel_time.to_i) % 1440
    player.save

    redirect_to root_path, notice: "#{route.to_location.name}へ移動した。#{route.travel_time}分経過した。"
  end

  def item_shop
    player = Player.first

    unless player.location&.safe_area? && player.found_item_shop?
      redirect_to root_path, alert: "道具屋はまだ利用できません。"
      return
    end

    result = ItemService.buy_potion!(player)
    redirect_to root_path(panel: "item_shop", shop_menu: "buy"), result.status == :ok ? { notice: result.message } : { alert: result.message }
  end

  def produce_item
    player = Player.first

    unless player.location&.safe_area? && player.found_item_shop?
      redirect_to root_path, alert: "道具屋はまだ利用できません。"
      return
    end

    result = ItemService.produce_potion!(player)
    redirect_to root_path(panel: "item_shop", shop_menu: "produce"), result.status == :ok ? { notice: result.message } : { alert: result.message }
  end

  def sell_item
    player = Player.first

    unless player.location&.safe_area? && player.found_item_shop?
      redirect_to root_path, alert: "道具屋はまだ利用できません。"
      return
    end

    item = player.items.find_by(name: params[:item_name])
    result = ItemService.sell_item!(player, item)
    redirect_to root_path(panel: "item_shop", shop_menu: "sell"), result.status == :ok ? { notice: result.message } : { alert: result.message }
  end

  def blacksmith
    player = Player.first

    unless player.location&.safe_area? && player.found_blacksmith?
      redirect_to root_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    weapon = player.equipped_weapon
    unless weapon
      redirect_to root_path, alert: "手入れする武器がありません。"
      return
    end

    price = weapon.repair_cost
    if price <= 0
      redirect_to root_path, notice: "#{weapon.name}は十分に手入れされています。"
      return
    end

    if player.col.to_i < price
      redirect_to root_path, alert: "コルが足りません。#{weapon.name}の手入れには#{price}コル必要です。"
      return
    end

    player.col = player.col.to_i - price
    player.current_time = (player.current_time.to_i + 20) % 1440
    weapon.durability = weapon.max_durability

    ActiveRecord::Base.transaction do
      player.save!
      weapon.save!
    end

    redirect_to root_path, notice: "鍛冶屋で#{weapon.name}を手入れした。耐久力が全回復した。#{price}コル支払った。"
  end

  def buy_bronze_sword
    player = Player.first

    unless player.location&.safe_area? && player.found_blacksmith?
      redirect_to root_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    price = 100
    if player.col.to_i < price
      redirect_to root_path(panel: "blacksmith", blacksmith_menu: "buy"), alert: "コルが足りません。ブロンズソードは#{price}コルです。"
      return
    end

    player.col = player.col.to_i - price
    player.weapons.create!(
      name: "ブロンズソード",
      weapon_type: "片手直剣",
      rarity: "common",
      attack_power: 9,
      durability: 40,
      max_durability: 40,
      hp_bonus: 0,
      strength_bonus: 2,
      agility_bonus: 0,
      critical_rate: 7,
      equipped: false
    )
    player.save!

    redirect_to root_path(panel: "equipment"), notice: "ブロンズソードを購入した。"
  end

  def sell_weapon
    player = Player.first

    unless player.location&.safe_area? && player.found_blacksmith?
      redirect_to root_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    weapon = player.weapons.find_by(id: params[:weapon_id])
    unless weapon
      redirect_to root_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "その武器は所持していません。"
      return
    end

    if weapon.starter_weapon?
      redirect_to root_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "スモールソードは売却できません。"
      return
    end

    price = weapon.sell_price
    player.col = player.col.to_i + price
    player.current_time = (player.current_time.to_i + 10) % 1440

    ActiveRecord::Base.transaction do
      weapon.destroy!
      player.save!
    end

    redirect_to root_path(panel: "blacksmith", blacksmith_menu: "sell"), notice: "#{weapon.name}を#{price}コルで売却した。"
  end

  def equip_weapon
    player = Player.first
    weapon = player.weapons.find_by(id: params[:weapon_id])

    unless weapon
      redirect_to root_path(panel: "equipment"), alert: "その武器は所持していません。"
      return
    end

    ActiveRecord::Base.transaction do
      if player.dual_wield?
        equipped_weapons = player.weapons.where(equipped: true).where.not(id: weapon.id).order(:updated_at)
        equipped_weapons.first.update!(equipped: false) if equipped_weapons.count >= 2
      else
        player.weapons.update_all(equipped: false)
      end

      weapon.update!(equipped: true)
    end

    redirect_to root_path(panel: "equipment"), notice: "#{weapon.name}を装備した。"
  end

  def unequip_weapon
    player = Player.first
    weapon = player.weapons.find_by(id: params[:weapon_id])

    unless weapon&.equipped?
      redirect_to root_path(panel: "equipment"), alert: "その武器は装備していません。"
      return
    end

    weapon.update!(equipped: false)
    redirect_to root_path(panel: "equipment"), notice: "#{weapon.name}を外した。"
  end

  def equip_armor
    player = Player.first
    armor = player.armors.find_by(id: params[:armor_id])

    unless armor
      redirect_to root_path(panel: "equipment"), alert: "その防具は所持していません。"
      return
    end

    ActiveRecord::Base.transaction do
      player.armors.where(slot: armor.slot).update_all(equipped: false)
      armor.update!(equipped: true)
    end

    redirect_to root_path(panel: "equipment"), notice: "#{armor.name}を装備した。"
  end

  def unequip_armor
    player = Player.first
    armor = player.armors.find_by(id: params[:armor_id])

    unless armor&.equipped?
      redirect_to root_path(panel: "equipment"), alert: "その防具は装備していません。"
      return
    end

    armor.update!(equipped: false)
    redirect_to root_path(panel: "equipment"), notice: "#{armor.name}を外した。"
  end

  def allocate_strength
    allocate_stat!(:strength, "筋力")
  end

  def allocate_agility
    allocate_stat!(:agility, "敏捷")
  end

  def inn
    player = Player.first

    unless player.location&.name == "はじまりの街"
      redirect_to root_path, alert: "宿屋ははじまりの街で利用できます。"
      return
    end

    unless player.found_inn?
      redirect_to root_path, alert: "宿屋はまだ見つけていません。"
      return
    end

    if Battle.exists?
      redirect_to root_path, alert: "戦闘中は宿屋を利用できません。"
      return
    end

    Rest.destroy_all
    player.hp = player.effective_max_hp
    player.current_time = (player.current_time.to_i + 60) % 1440
    player.save!

    redirect_to root_path, notice: "宿屋で休憩した。HPが全快した。"
  end

  private

  def available_routes_for(location)
    return [] unless location
    routes = location.outgoing_routes.includes(:to_location)
    return routes if location.safe_area?

    routes.select do |route|
      destination = route.to_location
      next false unless destination.safe_area?

      destination.name == "はじまりの街" || location.mapping_progress.to_i >= 100
    end
  end

  def calculate_player_damage(player, weapon, mob, part)
    base_damage = [player.effective_strength + weapon.attack_power.to_i - mob.durability.to_i, 1].max
    [(base_damage * part.damage_multiplier.to_i / 100.0).ceil, 1].max
  end

  def player_attack_hit?(player, battle, part)
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    part_modifier = part.weakness? ? -20 : 0
    chance = [[80 + (agility_gap * 5) + part_modifier, 20].max, 98].min
    rand(100) < chance
  end

  def ensure_mob_parts!(mob)
    return [] unless mob
    return mob.mob_parts.to_a if mob.mob_parts.exists?

    mob.mob_parts.create!(name: "本体", damage_multiplier: 100, weakness: true)
    mob.mob_parts.to_a
  end

  def gain_exp_message(player, mob)
    before_level = player.level.to_i
    before_slots = player.skill_slots.to_i
    amount = adjusted_exp_reward(player, mob)
    player.gain_exp!(amount)
    message = "#{amount}経験値獲得！"
    if player.level.to_i > before_level
      message += " レベル#{player.level}に上昇！振り分けポイント +3"
    end
    if player.skill_slots.to_i > before_slots
      message += " スキルスロット +#{player.skill_slots.to_i - before_slots}"
    end
    message
  end

  def adjusted_exp_reward(player, mob)
    level_gap = mob.effective_level - player.effective_level
    multiplier = 1.0 + (level_gap * 0.15)
    multiplier = [[multiplier, 0.1].max, 2.5].min
    [(mob.exp_reward.to_i * multiplier).round, 1].max
  end

  def resolve_player_attack!(label:, damage_multiplier:, durability_cost:, skill_gain:, stiffness:, hits:, sword_skill:)
    battle = Battle.last
    player = Player.first

    unless battle
      redirect_to root_path, alert: "戦闘中ではありません。"
      return
    end

    weapon = player.equipped_weapon
    unless weapon
      redirect_to root_path, alert: "装備中の武器がありません。"
      return
    end

    parts = ensure_mob_parts!(battle.mob)
    ensure_part_states!(battle, parts)
    part = parts.find { |mob_part| mob_part.id == params[:mob_part_id].to_i } || parts.first
    unless part
      redirect_to root_path, alert: "攻撃可能な部位がありません。"
      return
    end

    hit_messages = []
    damage = 0
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
        damage += hit_damage
        break_message = apply_part_damage!(player, battle, actual_part, hit_damage)
        critical_message = critical ? "クリティカル！" : ""
        result_message = "#{guard_result[:message]}#{critical_message}#{actual_part.name}へ#{hit_damage}ダメージ#{break_message}"
        hit_messages << hit_message(index, hits, result_message)
      else
        hit_messages << hit_message(index, hits, "#{guard_result[:message]}ミス")
      end
    end

    weapon.apply_durability_loss!(durability_cost)
    battle.enemy_hp -= damage

    if battle.enemy_hp <= 0
      finish_battle_victory!(player, battle, weapon, part, label, hit_messages.join(" / "), skill_gain, sword_skill)
      return
    end

    skill_message = sword_skill ? gain_sword_skill!(player, skill_gain) : ""

    player.save!
    battle.save!
    broken_message = destroy_weapon_if_broken!(weapon)
    enemy_message = apply_enemy_attack!(player, battle, battle.mob.name)
    return if performed?

    if stiffness
      stiffness_message = apply_enemy_attack!(player, battle, battle.mob.name, prefix: "ソードスキル後の硬直中、")
      return if performed?
    else
      stiffness_message = ""
    end

    redirect_to root_path, notice: "#{battle.mob.name}の#{part.name}へ#{label}！#{hit_messages.join(' / ')}！#{enemy_message}#{stiffness_message}#{broken_message}#{skill_message}"
  end

  def finish_battle_victory!(player, battle, weapon, part, label, damage_message, skill_gain, sword_skill)
    mob = battle.mob
    mob_name = mob.name
    player.col = player.col.to_i + 10

    skill_message = sword_skill ? gain_sword_skill!(player, skill_gain) : ""

    player.save!
    dropped_weapon_message = try_drop_weapon!(player, mob)
    exp_message = gain_exp_message(player, mob)
    battle.destroy!

    broken_message = destroy_weapon_if_broken!(weapon)
    redirect_to root_path, notice: "#{mob_name}の#{part.name}へ#{label}！#{damage_message}！10コル獲得！#{exp_message}#{dropped_weapon_message}#{broken_message}#{skill_message}"
  end

  def hit_message(index, hits, message)
    hits > 1 ? "#{index + 1}撃目 #{message}" : message
  end

  def apply_player_damage_variance(damage)
    [(damage.to_i * rand(75..100) / 100.0).ceil, 1].max
  end

  def critical_hit?(weapon, battle, part, damage)
    return true if part.weakness? && part_would_break?(battle, part, damage)

    rand(100) < weapon.effective_critical_rate
  end

  def part_would_break?(battle, part, damage)
    state = battle_part_states(battle)[part.id.to_s] || default_part_state(part)
    return false if state["broken"]

    state["durability"].to_i <= damage.to_i
  end

  def resolve_guarded_part(player, battle, parts, target_part)
    return { part: target_part, message: "", blocked: false } if part_broken?(battle, target_part)
    return { part: target_part, message: "", blocked: false } unless enemy_guard_success?(player, battle, target_part)

    if battle.mob.equipped_weapon && target_part.weakness?
      return { part: target_part, message: "#{battle.mob.equipped_weapon.name}で弾かれた！", blocked: true }
    end

    guard_part = guard_part_for(battle, parts, target_part)
    if guard_part
      { part: guard_part, message: "#{guard_part.name}で防がれた！", blocked: false }
    else
      { part: target_part, message: "", blocked: false }
    end
  end

  def enemy_guard_success?(player, battle, target_part)
    base_chance = target_part.weakness? ? 65 : 20
    base_chance += 15 if battle.mob.equipped_weapon && target_part.weakness?
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    chance = [[base_chance - (agility_gap * 6), 5].max, 90].min
    rand(100) < chance
  end

  def guard_part_for(battle, parts, target_part)
    candidates = parts.reject { |part| part.id == target_part.id || part_broken?(battle, part) }
    candidates.find { |part| part.name.match?(/手|腕/) } ||
      candidates.find { |part| part.name.match?(/外膜|胴|体/) } ||
      candidates.first
  end

  def apply_part_damage!(player, battle, part, damage)
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

  def apply_part_drop!(player, part)
    return "" if part.drop_item_name.blank?
    return "" unless rand(100) < part.drop_rate.to_i

    item = add_item!(player, part.drop_item_name, "drop")
    item.save!
    " #{part.drop_item_name}を入手した！"
  end

  def ensure_part_states!(battle, parts)
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

  def default_part_state(part)
    { "durability" => part.max_durability.to_i, "broken" => false }
  end

  def battle_part_states(battle)
    JSON.parse(battle.part_states.presence || "{}")
  rescue JSON::ParserError
    {}
  end

  def part_broken?(battle, part)
    battle_part_states(battle).dig(part.id.to_s, "broken") == true
  end

  def mob_effective_atk(battle)
    penalty = broken_parts_with_effect(battle, "strength_down").count * 0.35
    [(battle.mob.atk.to_i * (1.0 - penalty)).ceil, 1].max
  end

  def mob_effective_agility(battle)
    penalty = broken_parts_with_effect(battle, "agility_down").count * 0.35
    [(battle.mob.effective_agility * (1.0 - penalty)).ceil, 1].max
  end

  def broken_parts_with_effect(battle, effect)
    battle.mob.mob_parts.select do |part|
      part.break_effect == effect && part_broken?(battle, part)
    end
  end

  def apply_enemy_attack!(player, battle, mob_name, prefix: "")
    if evaded_enemy_attack?(player, battle)
      player.save!
      return "#{prefix}#{mob_name}の攻撃を回避した！"
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

      redirect_to root_path, notice: "#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！あなたは倒れた……。はじまりの街へ戻された。"
      return ""
    end

    player.save!
    "#{prefix}#{mob_name}の攻撃！#{enemy_damage}ダメージを受けた！"
  end

  def evaded_enemy_attack?(player, battle)
    agility_gap = player.effective_agility - mob_effective_agility(battle)
    chance = [[10 + (agility_gap * 5), 5].max, 75].min
    rand(100) < chance
  end

  def consume_healing_potion!(player)
    potion = player.items.find_by(name: "ポーション", category: "healing") || player.items.find_by(name: "ポーション")
    return false unless potion && potion.quantity.to_i.positive?

    potion.quantity -= 1
    player.hp = [player.hp.to_i + 100, player.effective_max_hp].min

    ActiveRecord::Base.transaction do
      potion.quantity.to_i <= 0 ? potion.destroy! : potion.save!
      player.save!
    end

    true
  end

  def add_item!(player, name, category, quantity = 1)
    item = player.items.find_or_create_by!(name: name, category: category) do |new_item|
      new_item.quantity = 0
    end
    item.quantity = item.quantity.to_i + quantity.to_i
    item
  end

  def gain_sword_skill!(player, amount)
    sword_skill = player.skills.find_or_create_by!(name: "片手剣") do |skill|
      skill.proficiency = 0
    end
    before = sword_skill.proficiency.to_i
    actual_gain = proficiency_gain(amount, before)
    sword_skill.proficiency = [before + actual_gain, 1000].min
    sword_skill.save!

    if before < 100 && sword_skill.proficiency >= 100
      " 片手剣 +#{actual_gain} バーチカルアークを習得した！"
    else
      " 片手剣 +#{actual_gain}"
    end
  end

  def proficiency_gain(base_amount, current_proficiency)
    reduction = current_proficiency.to_i / 100
    [base_amount.to_i - reduction, 1].max
  end

  def check_rest_encounter!(player)
    danger = (player.location&.danger_level || 0).to_i
    return if danger <= 0
    return unless rand(100) < (danger / 3)

    mob = Mob.order("RANDOM()").first
    return unless mob

    Rest.destroy_all
    Battle.destroy_all
    Battle.create!(player: player, mob: mob, enemy_hp: mob.hp)
    redirect_to root_path, alert: "休憩中に#{mob.name}に見つかった！"
  end

  def try_drop_weapon!(player, mob)
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

  def destroy_weapon_if_broken!(weapon)
    return "" unless weapon

    unless weapon.broken?
      weapon.save!
      return ""
    end

    name = weapon.name
    weapon.destroy!
    " #{name}は耐久力が尽きて破損した。"
  end

  def allocate_stat!(attribute, label)
    player = Player.first

    if player.stat_points.to_i <= 0
      redirect_to root_path, alert: "振り分けポイントがありません。"
      return
    end

    player.public_send("#{attribute}=", player.public_send(attribute).to_i + 1)
    player.stat_points -= 1
    player.save!

    redirect_to root_path(panel: "growth"), notice: "#{label}に1ポイント振り分けた。"
  end

  def check_item_use_surprise_encounter!(player)
    return "" if player.location&.safe_area?
    return "" unless rand(100) < 40

    mob = Mob.order("RANDOM()").first
    return "" unless mob

    Battle.destroy_all
    battle = Battle.create!(player: player, mob: mob, enemy_hp: mob.hp)
    apply_enemy_attack!(player, battle, mob.name, prefix: "アイテム使用中の不意打ち！")
    return "" if performed?

    "#{mob.name}に見つかった！"
  end

  def gather_encounter_chance(location)
    [[(location&.danger_level || 0).to_i / 2, 10].max, 45].min
  end

  def gatherable_items_for(location)
    case location&.name
    when "はじまりの草原"
      ["薬草"]
    when "静寂の森"
      ["薬草", "しなる枝"]
    else
      ["薬草"]
    end
  end
end
