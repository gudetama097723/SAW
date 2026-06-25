class FieldService
  Result = Struct.new(:status, :message, :battle, keyword_init: true)
  REQUIRED_MAPPING_TO_REACH_DESTINATION = 30
  ROAMING_AREA_BOSS_ENCOUNTER_RATE = 5

  def self.available_routes_for(player)
    location = player&.location
    return [] unless location
    return [player.field_route].compact if player.field_route.present?

    Route.includes(:from_location, :to_location).select do |route|
      route.from_location == location || route.to_location == location
    end
  end

  def self.explore!(player)
    route = player.field_route
    return Result.new(status: :error, message: "街中では探索できません。フィールドへ出てください。") unless route
    interruption = field_status_interruption!(player)
    return interruption if interruption

    area = current_area_for(player)
    area_progress = player.progress_for_area(area)
    mapping_before = area_progress&.mapping_progress.to_i
    destination_discovered_before = destination_discovered?(player, route)
    mapping_gain = mapping_gain_for(mapping_before, player, route)

    if area_progress
      area_progress.mapping_progress = [mapping_before + mapping_gain, 100].min
      area_progress.save!
    end

    player.advance_time!(10)
    previous_area = area
    advance = exploration_holds_position?(player, area, mapping_before) ? 0 : explore_advance_for(route, player)
    next_position = [player.field_position.to_i + advance, route.distance].min

    if area &&
      next_position > area.end_distance.to_i &&
      mapping_before < area.required_mapping_to_enter_next.to_i
      next_position = area.end_distance
    end

    player.field_position = next_position
    current_area = current_area_for(player)

    event = rand(100)
    encounter_rate = current_area_for(player)&.encounter_rate || field_danger_level(player)
    message =
      if event < encounter_rate
        battle = create_battle!(player, encounter_mobs_for(player))
        "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}と遭遇した！"
      elsif event < 80
        "何も見つからなかった。"
      else
        "遠くに奇妙な塔が見える……。"
      end

    message += " #{route.name}を探索した。"
    if previous_area && current_area && previous_area != current_area
      message += " [mapping]#{current_area.name}へ進んだ。[/mapping]"
    end
    mapping_after = area_progress&.mapping_progress.to_i
    mapping_added = mapping_after - mapping_before

    if area_progress && mapping_before < 100 && mapping_added.positive?
      message += " [mapping]#{area.name}の踏破度 +#{mapping_added}%（#{mapping_after}%）[/mapping]"
    end

    if area_progress && mapping_before < 100 && mapping_after >= 100
      message += " [mapping]#{area.name}を完全に把握した！[/mapping]"
    elsif !destination_discovered_before && destination_discovered?(player, route)
      message += " [mapping]#{route.to_location.name}を発見した！[/mapping]"
    end

    message += ExplorationRewardService.discoveries_after_explore!(player, area, mapping_before, mapping_after)

    player.save!
    Result.new(status: :ok, message: message, battle: battle)
  end

  def self.gather!(player)
    route = player.field_route
    return Result.new(status: :error, message: "街中では採取できません。フィールドへ出てください。") unless route
    interruption = field_status_interruption!(player)
    return interruption if interruption

    player.advance_time!(10)
    event = rand(100)

    if event < gather_encounter_chance(player)
      battle = create_battle!(player, encounter_mobs_for(player))
      message = "採取中に#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}と遭遇した！"
    elsif event < 75
      gathered = GatheringCatalog.roll_item(player)
      item = ItemService.add_item!(player, gathered.item_name, gathered.category)
      item.save!
      message = "#{gathered.item_name}を 1 個採取した。現在の所持数：#{item.quantity} 個"
    else
      message = "採取を試みたが、何も見つからなかった。"
    end

    player.save!
    Result.new(status: :ok, message: message, battle: battle)
  end

  def self.hunt!(player)
    route = player.field_route
    return Result.new(status: :error, message: "街中では狩りはできません。フィールドへ出てください。") unless route
    interruption = field_status_interruption!(player)
    return interruption if interruption

    player.advance_time!(15)

    if rand(100) < 85
      battle = create_battle!(player, encounter_mobs_for(player), ambush: true)
      message = "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}を発見した！先制攻撃のチャンス！"
    else
      message = "周辺を探したが、獲物は見つからなかった。"
    end

    player.save!
    Result.new(status: :ok, message: message, battle: battle)
  end
  
  def self.rest_encounter!(player)
    chance = rest_encounter_chance(player)
    return Result.new(status: :none) if chance <= 0
    return Result.new(status: :none) unless rand(100) < chance

    mobs = encounter_mobs_for(player)
    return Result.new(status: :none) if mobs.empty?

    player.rests.destroy_all
    destroyed_tent = destroy_best_portable_tent!(player)
    battle = create_battle!(player, mobs)
    tent_message = destroyed_tent ? "#{destroyed_tent.name}を壊された！" : ""
    Result.new(status: :encounter, message: "休憩中に#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に見つかった！#{tent_message}", battle: battle)
  end

  def self.item_use_surprise_encounter!(player)
    return Result.new(status: :none) unless player.field_route.present?
    return Result.new(status: :none) unless rand(100) < 40

    mobs = encounter_mobs_for(player)
    return Result.new(status: :none) if mobs.empty?

    battle = create_battle!(player, mobs)
    Result.new(status: :encounter, message: "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に見つかった！", battle: battle)
  end

  def self.movement_encounter!(player)
    return Result.new(status: :none) unless player.field_route.present?

    chance = [[field_danger_level(player) / 2, 8].max, 40].min
    return Result.new(status: :none) unless rand(100) < chance

    mobs = encounter_mobs_for(player)
    return Result.new(status: :none) if mobs.empty?

    battle = create_battle!(player, mobs)
    Result.new(status: :encounter, message: "移動中に#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}と遭遇した！", battle: battle)
  end

  def self.field_status_interruption!(player)
    return unless player.field_route.present?

    if StatusEffectService.active?(player, "paralysis")
      mobs = encounter_mobs_for(player)
      return Result.new(status: :none) if mobs.empty?

      battle = create_battle!(player, mobs, ambush: true)
      enemy_result = BattleService.apply_enemy_attack!(player, battle, prefix: "麻痺で動けないところを襲われた！", allow_evasion: false)
      return Result.new(status: :defeated, message: enemy_result.message, battle: battle) if enemy_result.status == :defeated

      return Result.new(status: :encounter, message: "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に襲われた！#{enemy_result.message}", battle: battle)
    end

    if StatusEffectService.active?(player, "sleep")
      player.rests.destroy_all
      heal = [(player.effective_max_hp * 0.01).ceil, 1].max
      player.hp = [player.hp.to_i + heal, player.effective_max_hp].min
      player.advance_time!(5)
      StatusEffectService.recover_values_percent!(player, 0.10)
      player.save!

      chance = [[field_danger_level(player), 0].max, 100].min
      if rand(100) >= chance
        StatusEffectService.cure!(player, "sleep")
        player.reset_sleep_deprivation!
        player.save!
        return Result.new(status: :ok, message: "その場で眠った。HPが#{heal}回復した。")
      end

      mobs = encounter_mobs_for(player)
      return Result.new(status: :none) if mobs.empty?

      battle = create_battle!(player, mobs, ambush: true)
      return Result.new(status: :encounter, message: "眠っているところを#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に襲われた！", battle: battle)
    end

    nil
  end

  def self.create_battle!(player, mobs, ambush: false)
    mobs = Array(mobs).compact
    first_mob = mobs.first
    return unless first_mob

    player.battles.destroy_all
    BuffEffectService.clear_battle_effects!(player)
    player.save!
    battle = Battle.create!(player: player, mob: first_mob, enemy_hp: first_mob.hp, ambush: ambush)
    mobs.first(5).each.with_index(1) do |mob, position|
      enemy_level = enemy_level_for(player.field_route, mob)
      enemy_max_hp = scaled_mob_value(mob.hp, enemy_level)
      battle.battle_enemies.create!(
        battle_enemy_attributes(
          mob: mob,
          enemy_hp: enemy_max_hp,
          enemy_max_hp: enemy_max_hp,
          enemy_level: enemy_level,
          position: position
        )
      )
    end
    battle
  end

  def self.enemy_level_for(route, mob)
    if route&.name == "はじまりの草原"
      roll = rand(100)
      return 1 if roll < 60
      return 2 if roll < 95
      return 3
    end

    [mob.level.to_i, 1].max
  end

  def self.scaled_mob_value(base, enemy_level)
    base_value = [base.to_i, 1].max
    multiplier = 1.0 + (([enemy_level.to_i, 1].max - 1) * 0.25)
    (base_value * multiplier).round
  end

  def self.battle_enemy_attributes(mob:, enemy_hp:, enemy_max_hp:, enemy_level:, position:)
    attrs = {
      mob: mob,
      enemy_hp: enemy_hp,
      position: position
    }

    probe = BattleEnemy.new
    attrs[:enemy_max_hp] = enemy_max_hp if probe.has_attribute?(:enemy_max_hp)
    attrs[:enemy_level] = enemy_level if probe.has_attribute?(:enemy_level)
    attrs
  end

  def self.encounter_mobs_for(player_or_route)
    if player_or_route.respond_to?(:field_route)
      roaming_boss = roaming_area_boss_for(player_or_route)
      return [roaming_boss] if roaming_boss
    end

    context = field_context(player_or_route)
    count = encounter_count_for(context)
    Array.new(count) { weighted_encounter_mob_for(context) }.compact
  end

  def self.roaming_area_boss_for(player)
    area = current_area_for(player)
    return unless area
    return unless rand(100) < ROAMING_AREA_BOSS_ENCOUNTER_RATE

    boss = Mob.find_by(field_area: area, boss_type: "area_boss")
    return unless boss

    kill = player.player_boss_kills.find_by(mob: boss)
    kill&.defeated? ? boss : nil
  end

  def self.weighted_encounter_mob_for(context)
    entries = encounter_entries_for(context)
    return Mob.order("RANDOM()").first if entries.empty?

    total_weight = entries.sum { |entry| entry[:weight] }
    roll = rand(total_weight)
    entries.each do |entry|
      roll -= entry[:weight]
      return entry[:mob] if roll < 0
    end
    entries.last[:mob]
  end

  def self.encounter_entries_for(context)
    field_name = field_name_for(context)
    rows = mob_spawn_rows.select { |row| row["location"] == field_name }
    rows.filter_map do |row|
      mob = Mob.find_by(name: row["mob"])
      weight = row["weight"].to_i
      next unless mob && weight.positive?

      { mob: mob, weight: weight }
    end
  end

  def self.mob_spawn_rows
    @mob_spawn_rows ||= begin
      path = Rails.root.join("db", "seeds", "mob_spawns.csv")
      rows = []
      SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
      rows
    end
  end

  def self.encounter_count_for(context)
    roll = rand(100)
    if field_name_for(context) == "はじまりの草原"
      return 5 if roll < 1
      return 4 if roll < 3
      return 3 if roll < 10
      return 2 if roll < 30
      1
    else
      danger = field_danger_level(context)
      return 5 if roll < danger - 35
      return 4 if roll < danger - 20
      return 3 if roll < danger
      return 2 if roll < danger + 25
      1
    end
  end

  def self.gather_encounter_chance(context)
    [[field_danger_level(context) / 2, 10].max, 45].min
  end

  def self.gatherable_items_for(context)
    GatheringCatalog.definitions_for(context).flat_map do |definition|
      [definition.item_name] * [definition.weight.to_i, 1].max
    end
  end

  def self.field_context(player_or_route)
    player_or_route.respond_to?(:field_route) ? player_or_route.field_route : player_or_route
  end

  def self.field_name_for(context)
    field_context(context)&.name.to_s
  end

  def self.field_danger_level(context)
    field_context(context)&.danger_level.to_i
  end

  def self.current_area_for(player)
    route = player&.field_route
    return unless route

    distance = player.field_position.to_i
    route.field_areas.ordered.find { |area| area.include_distance?(distance) }
  end

  def self.field_rest_available?(player)
    return false unless player&.field_route.present?
    return true if base_rest_encounter_chance(player) <= 0

    best_portable_tent(player).present?
  end

  def self.best_portable_tent(player)
    player.items.select { |item| item.portable_tent? && item.quantity.to_i.positive? }.max_by do |item|
      -item.tent_encounter_multiplier
    end
  end

  def self.destroy_best_portable_tent!(player)
    tent = best_portable_tent(player)
    return unless tent&.quantity.to_i&.positive?

    tent.quantity = tent.quantity.to_i - 1
    tent.quantity.to_i <= 0 ? tent.destroy! : tent.save!
    tent
  end

  def self.rest_encounter_chance(player)
    base_chance = base_rest_encounter_chance(player)
    return base_chance if base_chance <= 0

    tent = best_portable_tent(player)
    multiplier = tent&.tent_encounter_multiplier || 1.0
    (base_chance * multiplier).ceil.clamp(0, 100)
  end

  def self.base_rest_encounter_chance(player)
    area = current_area_for(player)
    return [[field_danger_level(player) / 3, 0].max, 100].min unless area

    (100 - area.rest_safety.to_i).clamp(0, 100)
  end

  def self.route_progress_for(player, route)
    player.player_route_progresses.find_or_create_by!(route: route)
  end

  def self.route_mapped?(player, route)
    areas = route.field_areas.ordered.to_a
    return false if areas.empty?

    areas_for_travel = areas[0...-1]
    return true if areas_for_travel.empty?

    progresses = player.player_field_area_progresses.where(field_area: areas_for_travel).index_by(&:field_area_id)

    areas_for_travel.all? do |area|
      progresses[area.id]&.mapping_progress.to_i >= area.required_mapping_to_enter_next.to_i
    end
  end

  def self.destination_discovered?(player, route)
    destination_area = route.field_areas.ordered.last
    return route_mapped?(player, route) unless destination_area

    progress = player.progress_for_area(destination_area)
    progress.mapping_progress.to_i >= destination_area.required_mapping_to_reach_town.to_i
  end

  def self.destination_reached?(player, route)
    route_progress_for(player, route).reached_destination?
  end

  def self.next_discovered_area_for(player, route)
    current_area = current_area_for(player)
    return unless current_area

    current_progress = player.progress_for_area(current_area)
    return if current_progress.mapping_progress.to_i < current_area.required_mapping_to_enter_next.to_i

    areas = route.field_areas.ordered.to_a
    index = areas.index(current_area)
    return unless index

    areas[index + 1]
  end

  def self.exploration_holds_position?(player, area, mapping_progress)
    return false unless area

    mapping_progress.to_i >= area.required_mapping_to_enter_next.to_i &&
      player.field_position.to_i >= area.start_distance.to_i
  end

  def self.explore_advance_for(route, player)
    distance = [route.distance.to_i, 1].max
    base = [[rand(8..16), (distance / 6.0).ceil].min, 1].max
    (base * player.movement_speed_multiplier).round.clamp(1, distance)
  end

  def self.mapping_gain_for(mapping_progress, player, route)
    gain =
      case mapping_progress.to_i
      when 0...30
        rand(2..4)
      when 30...60
        rand(2..3)
      when 60...80
        rand(1..2)
      when 80...90
        rand(0..1)
      else
        rand(0..1)
      end

    gain += 1 if player.skills.exists?(name: "探索")
    gain = (gain * player.movement_speed_multiplier).ceil
    difficulty = route.mapping_difficulty.to_f
    difficulty = 1.0 if difficulty <= 0
    (gain / difficulty).ceil
  end
end
