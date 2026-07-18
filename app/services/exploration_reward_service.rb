class ExplorationRewardService
  Result = Struct.new(:status, :message, :battle, keyword_init: true)
  FENRIR_NAME = "蒼狼フェンリル"
  PACK_LEADER_NAME = "群狼の王"
  FENRIR_REQUIRED_PACK_LEADER_DEFEATS = 5

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
    action = treasure_chest.requires_inspection? ? "開けた" : "回収した"
    Result.new(status: :ok, message: "#{treasure_chest.name}を#{action}。[treasure_reward]#{message}[/treasure_reward]")
  end

  def self.inspect_treasure!(player, treasure_chest)
    state = player.player_treasure_chests.find_or_create_by!(treasure_chest: treasure_chest)
    return Result.new(status: :error, message: "その宝箱はまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "その宝箱はすでに開封済みです。") if state.opened? && !treasure_chest.respawnable?
    unless treasure_chest.requires_inspection?
      return Result.new(status: :ok, message: "#{treasure_chest.name}は宝箱ではなさそうだ。すぐ回収できる。")
    end

    message = treasure_inspection_message(player, treasure_chest)
    state.update!(inspected: true, inspection_result: message)
    Result.new(status: :ok, message: message)
  end

  def self.use_treasure_skill!(player, treasure_chest, skill_name)
    state = player.player_treasure_chests.find_or_create_by!(treasure_chest: treasure_chest)
    return Result.new(status: :error, message: "その宝箱はまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "その宝箱はすでに開封済みです。") if state.opened? && !treasure_chest.respawnable?
    return Result.new(status: :error, message: "#{treasure_chest.name}には使えるスキルがありません。") unless treasure_chest.requires_inspection?

    skill = treasure_skill_for(player, skill_name)
    return Result.new(status: :error, message: "使用できるスキルを習得していません。") unless skill

    message = treasure_inspection_message(player, treasure_chest, skill: skill)
    state.update!(inspected: true, inspection_result: message)
    Result.new(status: :ok, message: message)
  end

  def self.ignore_treasure!(player, treasure_chest)
    state = player.player_treasure_chests.find_or_create_by!(treasure_chest: treasure_chest)
    return Result.new(status: :error, message: "その宝箱はまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "その宝箱はすでに開封済みです。") if state.opened? && !treasure_chest.respawnable?

    state.update!(ignored: true)
    Result.new(status: :ok, message: "#{treasure_chest.name}には手を出さず、場所だけ覚えておいた。")
  end

  def self.treasure_inspection_message(player, treasure_chest, skill: nil)
    threshold = treasure_inspection_threshold(player, treasure_chest, skill)
    success = rand(100) < threshold
    skill_message = award_treasure_skill_exp!(skill)

    result =
      case treasure_chest.hazard_type
      when "mimic"
        if success
          "#{treasure_chest.name}を調べた。箱の内側から、生き物のような気配がする。"
        else
          "#{treasure_chest.name}を調べた。普通の箱に見えるが、どこか落ち着かない。"
        end
      when "trap"
        if success
          "#{treasure_chest.name}を調べた。留め具の奥に罠の仕掛けを見つけた。"
        else
          "#{treasure_chest.name}を調べた。少し違和感はあるが、仕掛けまでは見抜けない。"
        end
      else
        "#{treasure_chest.name}を調べた。危険な仕掛けはなさそうだ。"
      end

    "#{result}#{skill_message}"
  end

  def self.treasure_inspection_threshold(player, treasure_chest, skill)
    base =
      case treasure_chest.hazard_type
      when "mimic"
        50 + ((player.effective_level - treasure_chest.hazard_level.to_i) * 10)
      when "trap"
        45 + ((player.effective_level - treasure_chest.hazard_level.to_i) * 8)
      else
        100
      end
    skill_bonus = skill ? (10 + (skill.proficiency.to_i / 50)).clamp(10, 30) : 0
    (base + skill_bonus).clamp(10, 95)
  end

  def self.treasure_skill_for(player, skill_name)
    usable_names = ["探索"]
    requested_name = skill_name.presence
    requested_name = usable_names.first unless requested_name.in?(usable_names)
    player.skills.find_by(name: requested_name)
  end

  def self.award_treasure_skill_exp!(skill)
    return "" unless skill

    growth = SkillGrowthCatalog.find(skill.name)
    before = skill.proficiency.to_i
    skill.gain_skill_exp!(growth.use_exp, growth_scale: growth.growth_scale)
    suffix = " 探索スキルを使って確認した。"
    suffix += " 探索の熟練度が#{skill.proficiency}に上がった。" if skill.proficiency.to_i > before
    suffix
  end

  def self.start_boss_battle!(player, mob)

    state = player.player_boss_kills.find_or_create_by!(mob: mob)
    return Result.new(status: :error, message: "そのボスはまだ発見していません。") unless state.found?
    return Result.new(status: :error, message: "#{mob.name}はすでに討伐済みです。") if state.defeated?
    return Result.new(status: :error, message: "この場所からは#{mob.name}に挑めません。") unless boss_challengeable_here?(player, mob)

    battle = FieldService.create_battle!(player, [mob])
    Result.new(status: :ok, message: "#{mob.name}に挑んだ！", battle: battle)
  end

  def self.boss_victory_message!(player, mob)
    return "" unless mob&.boss?

    state = player.player_boss_kills.find_or_create_by!(mob: mob)
    first_defeat = !state.defeated?

    state.defeated_count = state.defeated_count.to_i + 1
    state.found = true
    state.defeated = true
    state.defeated_at ||= Time.current
    state.save!

    message = " [boss]#{mob.name}を討伐した！[/boss]"
    message += apply_reward!(player, mob.reward, unique_drops: true) if first_defeat
    message
  end

  def self.discovered_treasures(player)
    discovered_treasure_states(player).map(&:treasure_chest)
  end

  def self.discovered_treasure_states(player)
    player.player_treasure_chests.includes(:treasure_chest).where(found: true, opened: false).select do |state|
      treasure_accessible_here?(player, state.treasure_chest)
    end
  end

  def self.pending_treasure_states(player)
    discovered_treasure_states(player).reject(&:ignored?)
  end

  def self.treasure_accessible_here?(player, treasure_chest)
    return false unless treasure_chest

    current_area = FieldService.current_area_for(player)
    if treasure_chest.field_area_id.present?
      current_area.present? && treasure_chest.field_area_id == current_area.id
    else
      player.field_route_id.present? && treasure_chest.route_id == player.field_route_id
    end
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

    boss = Mob.find_by(route: route, boss_type: "field_boss")
    return unless field_boss_discoverable?(player, boss)

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
        field_boss_discoverable?(player, mob)
    else
      false
    end
  end

  def self.field_boss_discoverable?(player, mob)
    return false unless mob&.field_boss?
    return false unless player.field_route.present?
    return false unless mob.route_id == player.field_route_id
    return false unless player.field_route_mapping_progress >= 100
    return true unless mob.name == FENRIR_NAME

    pack_leader_defeat_count(player) >= FENRIR_REQUIRED_PACK_LEADER_DEFEATS
  end

  def self.pack_leader_defeat_count(player)
    pack_leader = Mob.find_by(name: PACK_LEADER_NAME)
    return 0 unless pack_leader

    state = player.player_boss_kills.find_by(mob: pack_leader)
    return 0 unless state
    state.defeated_count.to_i
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
      messages << "#{col}刻銭を入手した。"
    end

    Array(reward["items"]).each do |item_reward|
      category = item_reward["category"].presence || "drop"
      if category == "key_item"
        player.obtain_key_item!(
          name: item_reward["name"],
          description: item_reward["description"],
          category: item_reward["key_item_category"].presence || item_reward["key_category"].presence || "map",
          unique_key: item_reward["unique_key"].presence || item_reward["name"].to_s
        )
        messages << "#{item_reward["name"]}を入手した。"
        next
      end

      unique = item_reward["unique_item"] == true || item_reward["unique_item"].to_s.downcase == "true" || (unique_drops && category == "drop")
      item = ItemService.add_item!(player, item_reward["name"], category, item_reward["quantity"].presence || 1, unique: unique)
      item.save!
      messages << "#{item_reward["name"]}を#{item_reward["quantity"].presence || 1}個入手した。"
    end

    player.save!
    messages.join
  end
end
