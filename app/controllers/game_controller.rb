class GameController < ApplicationController
  before_action :require_login

  def index
    @player = current_player
    @battle = current_battle
    @rest = current_rest
    @routes = FieldService.available_routes_for(@player)
    @town_discovery = @player.town_discovery_for if @player.location&.safe_area?
    if @battle
      BattleService.ensure_battle_enemies!(@battle)
      @battle_enemies = @battle.alive_enemies.includes(mob: :mob_parts).to_a
      @part_states_by_enemy = @battle_enemies.to_h do |battle_enemy|
        parts = BattleService.ensure_mob_parts!(battle_enemy.mob)
        [battle_enemy.id, BattleService.ensure_part_states!(battle_enemy, parts)]
      end
    end
    @active_route_progress = @player.player_route_progresses.includes(route: [:from_location, :to_location]).first
  end

  def stroll
    player = current_player

    unless player.location&.safe_area?
      redirect_to game_path, alert: "ここは安全地帯ではありません。"
      return
    end

    result = rand(100)
    next_time = (player.current_time.to_i + 10) % 1440
    discovery = player.town_discovery_for

    if !discovery.found_inn? && result < 30
      discovery.found_inn = true
      player.current_time = next_time
      ActiveRecord::Base.transaction { discovery.save!; player.save! }
      redirect_to game_path, notice: "広場の近くで宿屋を見つけた！"
    elsif !discovery.found_item_shop? && result < 60
      discovery.found_item_shop = true
      player.current_time = next_time
      ActiveRecord::Base.transaction { discovery.save!; player.save! }
      redirect_to game_path, notice: "街を散策していると、道具屋を見つけた！"
    elsif !discovery.found_blacksmith? && result < 85
      discovery.found_blacksmith = true
      player.current_time = next_time
      ActiveRecord::Base.transaction { discovery.save!; player.save! }
      redirect_to game_path, notice: "路地裏で鍛冶屋を見つけた！"
    else
      player.update!(current_time: next_time)
      redirect_to game_path, notice: "街を散策した。特に新しい発見はなかった。"
    end
  end

  def explore
    result = FieldService.explore!(current_player)
    redirect_with_result(result, battle_command: "attack", target_enemy_id: params[:target_enemy_id])
  end

  def gather
    result = FieldService.gather!(current_player)
    redirect_with_result(result)
  end

  def hunt
    result = FieldService.hunt!(current_player)
    redirect_to game_path, notice: result.message
  end

  def attack
    result = BattleService.resolve_player_attack!(
      battle: current_battle,
      player: current_player,
      mob_part_id: params[:mob_part_id],
      target_enemy_id: params[:target_enemy_id],
      label: "通常攻撃",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false
    )
    redirect_with_result(result, battle_command: "attack", target_enemy_id: params[:target_enemy_id])
  end

  def sword_skill
    skill_key = params[:skill].presence || "vertical"
    player = current_player
    sword_skill = player.skills.find_by(name: "片手剣")
    proficiency = sword_skill&.proficiency.to_i
    skill_config = sword_skill_config(skill_key)

    unless proficiency >= skill_config[:required]
      redirect_to game_path(battle_command: "sword_skill", selected_skill: skill_key), alert: "#{skill_config[:label]}はまだ習得していません。"
      return
    end

    result = BattleService.resolve_player_attack!(
      battle: current_battle,
      player: player,
      mob_part_id: params[:mob_part_id],
      target_enemy_id: params[:target_enemy_id],
      group_start: params[:group_start],
      label: skill_config[:label],
      damage_multiplier: skill_config[:damage_multiplier],
      durability_cost: skill_config[:durability_cost],
      skill_gain: skill_config[:skill_gain],
      stiffness: true,
      hits: skill_config[:hits],
      sword_skill: true,
      area: skill_config[:area]
    )
    redirect_with_result(
      result,
      battle_command: "sword_skill",
      selected_skill: skill_key,
      target_enemy_id: params[:target_enemy_id],
      group_start: params[:group_start]
    )
  end

  def use_battle_item
    battle = current_battle
    player = current_player

    unless battle
      redirect_to game_path, alert: "戦闘中ではありません。"
      return
    end

    unless params[:item_name] == "ポーション"
      redirect_to game_path(battle_command: "item"), alert: "そのアイテムはまだ使用できません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to game_path(battle_command: "item"), alert: item_result.message
      return
    end

    enemy_result = BattleService.apply_enemy_attack!(player, battle)

    redirect_to game_path(battle_command: "item"), notice: "#{item_result.message}#{enemy_result.message}"
  end

  def use_item
    player = current_player

    if current_player.battles.exists?
      redirect_to game_path(battle_command: "item"), alert: "戦闘中は戦闘コマンドからアイテムを使ってください。"
      return
    end

    unless params[:item_name] == "ポーション"
      redirect_to game_path(panel: "items", item_category: "healing"), alert: "そのアイテムはまだ使用できません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to game_path(panel: "items", item_category: "healing"), alert: item_result.message
      return
    end

    player.current_time = (player.current_time.to_i + 10) % 1440
    player.save!

    surprise_message = check_item_use_surprise_encounter!(player)
    return if performed?

    redirect_to game_path(panel: "items", item_category: "healing"), notice: "#{item_result.message}#{surprise_message}"
  end

  def escape
    battle = current_battle
    player = current_player

    unless battle
      redirect_to game_path, alert: "戦闘中ではありません。"
      return
    end

    BattleService.ensure_battle_enemies!(battle)
    alive_enemies = battle.alive_enemies.to_a
    enemy_agility = alive_enemies.map { |battle_enemy| BattleService.mob_effective_agility(battle_enemy) }.max.to_i
    agility_gap = player.effective_agility - enemy_agility
    enemy_count_penalty = [alive_enemies.size - 1, 0].max * 12
    chance = [[50 + agility_gap * 10 - enemy_count_penalty, 5].max, 95].min
    if rand(100) < chance
      battle.destroy
      redirect_to game_path, notice: "逃走に成功した。"
    else
      enemy_result = BattleService.apply_enemy_attack!(player, battle)

      redirect_to game_path(battle_command: params[:battle_command].presence), alert: "逃走に失敗した。#{enemy_result.message}"
    end
  end

  def start_rest
    player = current_player

    if current_player.battles.exists?
      redirect_to game_path, notice: "戦闘中は休憩できない！"
      return
    end

    unless player.field_route.present?
      redirect_to game_path, notice: "街中では休憩コマンドを使用できません。"
      return
    end

    danger = FieldService.field_danger_level(player)

    if rand(100) < danger
      redirect_to game_path, notice: "周囲に敵の気配があり、休憩できなかった。"
    else
      current_player.rests.destroy_all
      Rest.create!(player: player)
      redirect_to game_path, notice: "休憩を開始した。"
    end
  end

  def use_rest_skill
    player = current_player
    rest = current_rest

    unless rest
      redirect_to game_path, notice: "休憩中ではない。"
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

      redirect_to game_path, notice: "スキル《昼寝》を使用した。HPが#{heal}回復した。"
    else
      redirect_to game_path, notice: "スキル《昼寝》を習得していない。"
    end
  end

  def use_rest_item
    player = current_player
    rest = current_rest

    unless rest
      redirect_to game_path, alert: "休憩中ではありません。"
      return
    end

    item_result = ItemService.consume_healing_potion!(player)
    unless item_result.status == :ok
      redirect_to game_path, alert: item_result.message
      return
    end

    player.current_time = (player.current_time.to_i + 10) % 1440
    player.save!

    check_rest_encounter!(player)
    return if performed?

    redirect_to game_path, notice: item_result.message
  end

  def end_rest
    current_player.rests.destroy_all
    redirect_to game_path, notice: "休憩を終えた。"
  end

  def move
    player = current_player
    route = Route.find(params[:route_id])

    if player.battles.exists?
      redirect_to game_path, notice: "戦闘中は移動できない！"
      return
    end

    if player.rests.exists?
      redirect_to game_path, notice: "休憩中は移動できない！"
      return
    end

    unless FieldService.available_routes_for(player).include?(route)
      redirect_to game_path, notice: "このルートには入れない。"
      return
    end

    # まだフィールド上にいない場合：町/村からフィールドに出る
    if player.field_route.blank?
      player.field_route = route

      if player.location == route.from_location
        player.field_position = 0
      elsif player.location == route.to_location
        player.field_position = route.distance
      else
        redirect_to game_path, notice: "このルートには入れない。"
        return
      end

      player.current_time = (player.current_time.to_i + 5) % 1440
      player.save!

      redirect_to game_path, notice: "#{route.name}に出た。"
      return
    end

    # すでにフィールド上にいる場合：フィールド内を進む
    unless player.field_route == route
      redirect_to game_path, notice: "現在進行中のフィールド以外には移動できない。"
      return
    end

    unless FieldService.destination_discovered?(player, route)
      redirect_to game_path, notice: "まだ目的地への道筋が掴めていない。探索でマッピングを進めよう。"
      return
    end

    advance = rand(15..25)
    direction = params[:direction]
    reached_destination = FieldService.destination_reached?(player, route)

    if direction == "backward" && !reached_destination
      redirect_to game_path, notice: "まだ#{route.from_location.name}方面へ戻る道筋は整理できていない。まずは#{route.to_location.name}を目指そう。"
      return
    end

    if direction == "backward"
      player.field_position -= advance
      direction_text = route.from_location.name
    else
      player.field_position += advance
      direction_text = route.to_location.name
    end

    elapsed_time = rand(10..20)
    player.current_time = (player.current_time.to_i + elapsed_time) % 1440

    if player.field_position <= 0
      player.location = route.from_location
      player.field_route = nil
      player.field_position = 0
      player.save!

      redirect_to game_path, notice: "#{route.from_location.name}へ到着した。#{elapsed_time}分経過した。"
      return
    end

    if player.field_position >= route.distance
      unless FieldService.route_mapped?(player, route)
        player.field_position = [route.distance - 10, 0].max
        player.save!
        redirect_to game_path, notice: "#{route.name}の奥まで進んだが、まだ目的地への道筋が掴めていない。探索でマッピングを進めよう。"
        return
      end

      player.location = route.to_location
      player.field_route = nil
      player.field_position = 0
      FieldService.route_progress_for(player, route).update!(reached_destination: true)
      player.save!

      redirect_to game_path, notice: "#{route.to_location.name}へ到着した。#{elapsed_time}分経過した。"
      return
    end

    player.save!
    encounter_result = FieldService.movement_encounter!(player)
    if encounter_result.status == :encounter
      redirect_to game_path, alert: "#{route.name}を#{direction_text}方面へ進んだ。#{elapsed_time}分経過した。#{encounter_result.message}"
      return
    end

    redirect_to game_path, notice: "#{route.name}を#{direction_text}方面へ進んだ。#{elapsed_time}分経過した。"
  end

  def item_shop
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
      redirect_to game_path, alert: "道具屋はまだ利用できません。"
      return
    end

    result = ItemService.buy_shop_item!(player, params[:item_name].presence || "ポーション")
    redirect_to game_path(panel: "item_shop", shop_menu: "buy"), flash_for(result)
  end

  def produce_item
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
      redirect_to game_path, alert: "道具屋はまだ利用できません。"
      return
    end

    result = ItemService.produce_potion!(player)
    redirect_to game_path(panel: "item_shop", shop_menu: "produce"), flash_for(result)
  end

  def sell_item
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
      redirect_to game_path, alert: "道具屋はまだ利用できません。"
      return
    end

    item = player.items.find_by(name: params[:item_name])
    result = ItemService.sell_item!(player, item)
    redirect_to game_path(panel: "item_shop", shop_menu: "sell"), flash_for(result)
  end

  def toggle_route_direction
    player = current_player
    progress = player.player_route_progresses.find(params[:progress_id])

    progress.update!(returning: !progress.returning?)

    message =
      if progress.returning?
        "引き返すことにした。"
      else
        "再び目的地へ向かうことにした。"
      end

    redirect_to game_path, notice: message
  end

  def blacksmith
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
      redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    weapon = player.equipped_weapon
    unless weapon
      redirect_to game_path, alert: "手入れする武器がありません。"
      return
    end

    price = weapon.repair_cost
    if price <= 0
      redirect_to game_path, notice: "#{weapon.name}は十分に手入れされています。"
      return
    end

    if player.col.to_i < price
      redirect_to game_path, alert: "コルが足りません。#{weapon.name}の手入れには#{price}コル必要です。"
      return
    end

    player.col = player.col.to_i - price
    player.current_time = (player.current_time.to_i + 20) % 1440
    weapon.durability = weapon.max_durability

    ActiveRecord::Base.transaction do
      player.save!
      weapon.save!
    end

    redirect_to game_path, notice: "鍛冶屋で#{weapon.name}を手入れした。耐久力が全回復した。#{price}コル支払った。"
  end

  def buy_bronze_sword
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
      redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    weapon_definition = ShopCatalog.blacksmith_weapon(player.location, params[:weapon_name].presence || "ブロンズソード")
    unless weapon_definition
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "buy"), alert: "この町ではその武器を購入できません。"
      return
    end

    price = weapon_definition.price
    if player.col.to_i < price
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "buy"), alert: "コルが足りません。#{weapon_definition.name}は#{price}コルです。"
      return
    end

    player.col = player.col.to_i - price
    player.weapons.create!(
      name: weapon_definition.name,
      weapon_type: weapon_definition.weapon_type,
      rarity: weapon_definition.rarity,
      attack_power: weapon_definition.attack_power,
      durability: weapon_definition.durability,
      max_durability: weapon_definition.max_durability,
      hp_bonus: weapon_definition.hp_bonus,
      strength_bonus: weapon_definition.strength_bonus,
      agility_bonus: weapon_definition.agility_bonus,
      critical_rate: weapon_definition.critical_rate,
      part_break_power: weapon_definition.part_break_power,
      equipped: false
    )
    player.save!

    redirect_to game_path(panel: "equipment"), notice: "#{weapon_definition.name}を購入した。"
  end

  def sell_weapon
    player = current_player

    unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
      redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    weapon = player.weapons.find_by(id: params[:weapon_id])
    unless weapon
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "その武器は所持していません。"
      return
    end

    if weapon.starter_weapon?
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "スモールソードは売却できません。"
      return
    end

    price = weapon.sell_price
    player.col = player.col.to_i + price
    player.current_time = (player.current_time.to_i + 10) % 1440

    ActiveRecord::Base.transaction do
      weapon.destroy!
      player.save!
    end

    redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), notice: "#{weapon.name}を#{price}コルで売却した。"
  end

  def equip_weapon
    player = current_player
    battle = current_battle
    weapon = player.weapons.find_by(id: params[:weapon_id])

    unless weapon
      redirect_to game_path(panel: "equipment"), alert: "その武器は所持していません。"
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

    if battle
      enemy_result = BattleService.apply_enemy_attack!(player, battle)
      if enemy_result.status == :defeated
        redirect_to game_path, alert: "#{weapon.name}を装備した。#{enemy_result.message}"
      else
        redirect_to game_path(battle_command: "attack"), notice: "#{weapon.name}を装備した。#{enemy_result.message}"
      end
      return
    end

    redirect_to game_path(panel: "equipment"), notice: "#{weapon.name}を装備した。"
  end

  def unequip_weapon
    player = current_player
    weapon = player.weapons.find_by(id: params[:weapon_id])

    unless weapon&.equipped?
      redirect_to game_path(panel: "equipment"), alert: "その武器は装備していません。"
      return
    end

    weapon.update!(equipped: false)
    redirect_to game_path(panel: "equipment"), notice: "#{weapon.name}を外した。"
  end

  def equip_armor
    player = current_player
    armor = player.armors.find_by(id: params[:armor_id])

    unless armor
      redirect_to game_path(panel: "equipment"), alert: "その防具は所持していません。"
      return
    end

    ActiveRecord::Base.transaction do
      player.armors.where(slot: armor.slot).update_all(equipped: false)
      armor.update!(equipped: true)
    end

    redirect_to game_path(panel: "equipment"), notice: "#{armor.name}を装備した。"
  end

  def unequip_armor
    player = current_player
    armor = player.armors.find_by(id: params[:armor_id])

    unless armor&.equipped?
      redirect_to game_path(panel: "equipment"), alert: "その防具は装備していません。"
      return
    end

    armor.update!(equipped: false)
    redirect_to game_path(panel: "equipment"), notice: "#{armor.name}を外した。"
  end

  def allocate_strength
    allocate_stat!(:strength, "筋力")
  end

  def allocate_agility
    allocate_stat!(:agility, "敏捷")
  end

  def inn
    player = current_player

    unless player.location&.safe_area?
      redirect_to game_path, alert: "宿屋は街で利用できます。"
      return
    end

    unless player.town_discovery_for&.found_inn?
      redirect_to game_path, alert: "宿屋はまだ見つけていません。"
      return
    end

    if current_player.battles.exists?
      redirect_to game_path, alert: "戦闘中は宿屋を利用できません。"
      return
    end

    cost = inn_cost_for(player.location)
    if player.col.to_i < cost
      redirect_to game_path, alert: "コルが足りません。宿屋で休むには#{cost}コル必要です。"
      return
    end

    current_player.rests.destroy_all
    player.col = player.col.to_i - cost
    player.hp = player.effective_max_hp
    player.current_time = (player.current_time.to_i + 60) % 1440
    player.save!

    payment_message = cost.positive? ? "#{cost}コル支払った。" : ""
    redirect_to game_path, notice: "宿屋で休憩した。#{payment_message}HPが全快した。"
  end

  private

  def current_battle
    current_player.battles.order(:created_at).last
  end

  def current_rest
    current_player.rests.order(:created_at).last
  end


  def check_rest_encounter!(player)
    result = FieldService.rest_encounter!(player)
    if result.status == :encounter
      redirect_to game_path, alert: result.message
      return ""
    end
  end

  def allocate_stat!(attribute, label)
    player = current_player

    if player.stat_points.to_i <= 0
      redirect_to game_path, alert: "振り分けポイントがありません。"
      return
    end

    player.public_send("#{attribute}=", player.public_send(attribute).to_i + 1)
    player.stat_points -= 1
    player.save!

    redirect_to game_path(panel: "growth"), notice: "#{label}に1ポイント振り分けた。"
  end

  def check_item_use_surprise_encounter!(player)
    encounter = FieldService.item_use_surprise_encounter!(player)
    return "" unless encounter.status == :encounter

    enemy_result = BattleService.apply_enemy_attack!(player, encounter.battle, prefix: "アイテム使用中の不意打ち！")
    return enemy_result.message if enemy_result.status == :defeated

    "#{encounter.message}#{enemy_result.message}"
  end

  def redirect_with_result(result, path_options = {})
    path_options.compact!
    if result.status == :error
      redirect_to game_path(path_options), alert: result.message
    else
      redirect_to game_path(path_options), notice: result.message
    end
  end

  def sword_skill_config(skill_key)
    skill = SkillCatalog.find(skill_key)
    {
      label: skill.name,
      required: skill.required_proficiency,
      damage_multiplier: skill.damage_multiplier,
      durability_cost: skill.durability_cost,
      skill_gain: skill.skill_gain,
      hits: skill.hits,
      area: skill.area?
    }
  end

  def flash_for(result)
    result.status == :ok ? { notice: result.message } : { alert: result.message }
  end

  def inn_cost_for(location)
    case location&.name
    when "ホルンカの村"
      50
    else
      0
    end
  end
end
