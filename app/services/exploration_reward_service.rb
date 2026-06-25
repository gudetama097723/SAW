class ExplorationRewardService
  Result = Struct.new(:status, :message, :battle, keyword_init: true)

  def self.discoveries_after_explore!(player, area, mapping_before, mapping_after)
    messages = []
    messages << discover_fixed_treasure!(player, area)
    messages << discover_mapping_treasure!(player, area, mapping_after)
    messages << discover_area_boss!(player, area, mapping_before, mapping_after)
    messages << discover_field_boss!(player)
    messages.compact.join
  end

  def self.open_treasure!(player, treasure_chest)
    state = player.player_treasure_chests.find_or_create_by!(treasure_chest: treasure_chest)
    return Result.new(status: :error, message: "その宝箱はまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "その宝箱はすでに開封済みです。") if state.opened? && !treasure_chest.respawnable?

    message = apply_reward!(player, treasure_chest.reward)
    state.update!(opened: true, opened_at: Time.current)
    Result.new(status: :ok, message: "#{treasure_chest.name}を開けた。#{message}")
  end

def self.treasure_inspection_message(player, treasure_chest)
  case treasure_chest.hazard_type
  when "mimic"
    threshold = 50 + ((player.effective_level - treasure_chest.hazard_level.to_i) * 10)
    threshold = threshold.clamp(10, 90)
    rand(100) < threshold ? "#{treasure_chest.name}??????????????????" : "#{treasure_chest.name}??????????????????"
  when "trap"
    threshold = 45 + ((player.effective_level - treasure_chest.hazard_level.to_i) * 8)
    threshold = threshold.clamp(10, 85)
    rand(100) < threshold ? "#{treasure_chest.name}?????????????" : "#{treasure_chest.name}??????????????????"
  else
    "#{treasure_chest.name}???????????????"
  end
end

def self.treasure_hazard_message(treasure_chest, inspected: false)
  case treasure_chest.hazard_type
  when "mimic"
    inspected ? "????????????" : "???????????"
  when "trap"
    inspected ? "????????????" : "???????"
  else
    ""
  end
end

def self.start_boss_battle!(player, mob)

    state = player.player_boss_kills.find_or_create_by!(mob: mob)
    return Result.new(status: :error, message: "そのボスはまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "#{mob.name}はすでに討伐済みです。") if state.defeated?
    return Result.new(status: :error, message: "この場所からは#{mob.name}に挑めません。") unless boss_challengeable_here?(player, mob)

    battle = FieldService.create_battle!(player, [mob], ambush: true)
    Result.new(status: :ok, message: "#{mob.name}に挑んだ！", battle: battle)
  end

  def self.boss_victory_message!(player, mob)
    return "" unless mob&.boss?

    state = player.player_boss_kills.find_or_create_by!(mob: mob)
    return "" if state.defeated?

    state.update!(found: true, defeated: true, defeated_at: Time.current)
    " #{mob.name}を討伐した！#{apply_reward!(player, mob.reward, unique_drops: true)}"
  end

  def self.discovered_treasures(player)
    player.player_treasure_chests.includes(:treasure_chest).where(found: true, opened: false).map(&:treasure_chest)
  end

  def self.discovered_bosses(player)
    sync_discovered_bosses!(player)
    player.player_boss_kills.includes(:mob).where(found: true, defeated: false).map(&:mob).select do |mob|
      boss_challengeable_here?(player, mob)
    end
  end

  def self.discover_fixed_treasure!(player, area)
    return unless area

    chest = area.treasure_chests.fixed.available_at(player.field_position).find do |treasure|
      treasure.required_mapping.to_i <= player.progress_for_area(area).mapping_progress.to_i &&
        !player.player_treasure_chests.find_by(treasure_chest: treasure)&.opened?
    end
    mark_treasure_found!(player, chest)
  end

  def self.discover_mapping_treasure!(player, area, mapping_after)
    return unless area

    chest = area.treasure_chests.mapping.find do |treasure|
      mapping_after.to_i >= treasure.required_mapping.to_i &&
        !player.player_treasure_chests.find_by(treasure_chest: treasure)&.opened?
    end
    mark_treasure_found!(player, chest)
  end

  def self.discover_area_boss!(player, area, mapping_before, mapping_after)
    return unless area
    return unless mapping_after.to_i >= 100

    boss = Mob.find_by(field_area: area, boss_type: "area_boss")
    mark_boss_found!(player, boss, "#{area.name}の探索率が100%に到達した。")
  end

  def self.discover_field_boss!(player)
    route = player.field_route
    return unless route
    return unless player.field_route_mapping_progress >= 100

    boss = Mob.find_by(route: route, boss_type: "field_boss")
    mark_boss_found!(player, boss, "#{route.name}のマッピング率が100%に到達した。")
  end

  def self.sync_discovered_bosses!(player)
    area = FieldService.current_area_for(player)
    if area && player.progress_for_area(area).mapping_progress.to_i >= 100
      boss = Mob.find_by(field_area: area, boss_type: "area_boss")
      mark_boss_found!(player, boss, "#{area.name}の探索率が100%に到達した。")
    end

    discover_field_boss!(player)
  end

  def self.boss_challengeable_here?(player, mob)
    return false unless mob&.boss?

    case mob.boss_type
    when "area_boss"
      area = FieldService.current_area_for(player)
      area.present? &&
        mob.field_area_id == area.id &&
        player.progress_for_area(area).mapping_progress.to_i >= 100
    when "field_boss"
      player.field_route.present? &&
        mob.route_id == player.field_route_id &&
        player.field_route_mapping_progress >= 100
    else
      false
    end
  end

  def self.mark_treasure_found!(player, chest)
    return unless chest

    state = player.player_treasure_chests.find_or_create_by!(treasure_chest: chest)
    return if state.found? || state.opened?

    state.update!(found: true)
    " #{chest.name}を発見した！"
  end

  def self.mark_boss_found!(player, boss, prefix)
    return unless boss

    state = player.player_boss_kills.find_or_create_by!(mob: boss)
    return if state.found? || state.defeated?

    state.update!(found: true)
    " #{prefix}#{boss.boss_type == "field_boss" ? "フィールドボス" : "エリア中ボス"}「#{boss.name}」を発見した！"
  end

  def self.apply_reward!(player, reward, unique_drops: false)
    messages = []
    col = reward["col"].to_i
    if col.positive?
      player.col = player.col.to_i + col
      messages << "#{col}コルを入手した。"
    end

    Array(reward["items"]).each do |item_reward|
      category = item_reward["category"].presence || "drop"
      unique = item_reward["unique_item"] == true || item_reward["unique_item"].to_s.downcase == "true" || (unique_drops && category == "drop")
      item = ItemService.add_item!(player, item_reward["name"], category, item_reward["quantity"].presence || 1, unique: unique)
      item.save!
      messages << "#{item_reward["name"]}を#{item_reward["quantity"].presence || 1}個入手した。"
    end

    player.save!
    messages.join
  end
end
