class FieldService
  Result = Struct.new(:status, :message, :battle, keyword_init: true)

  def self.available_routes_for(location)
    return [] unless location

    routes = location.outgoing_routes.includes(:to_location)
    return routes if location.safe_area?

    routes.select do |route|
      destination = route.to_location
      next false unless destination.safe_area?

      destination.name == "はじまりの街" || location.mapping_progress.to_i >= 100
    end
  end

  def self.explore!(player)
    location = player.location
    return Result.new(status: :error, message: "ここは安全地帯です。敵は出現しません。") if location&.safe_area?

    mapping_before = location.mapping_progress.to_i
    mapping_gain = rand(12..22)
    location.mapping_progress = [mapping_before + mapping_gain, 100].min
    location.save!

    event = rand(100)
    message =
      if event < 40
        battle = create_battle!(player, encounter_mobs_for(location))
        "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}と遭遇した！"
      elsif event < 80
        "何も見つからなかった。"
      else
        "遠くに奇妙な塔が見える……。"
      end

    message += " マッピング進行度 +#{location.mapping_progress - mapping_before}%（#{location.mapping_progress}%）"
    if mapping_before < 100 && location.mapping_progress >= 100
      message += " #{location.name}の地形を把握した。次の町への道が開けた！"
    end

    player.save!
    Result.new(status: :ok, message: message, battle: battle)
  end

  def self.gather!(player)
    location = player.location
    return Result.new(status: :error, message: "街中では採取できません。") if location&.safe_area?

    player.current_time = (player.current_time.to_i + 10) % 1440
    event = rand(100)

    if event < gather_encounter_chance(location)
      battle = create_battle!(player, encounter_mobs_for(location))
      message = "採取中に#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}と遭遇した！"
    elsif event < 75
      item_name = gatherable_items_for(location).sample
      item = ItemService.add_item!(player, item_name, "gathered")
      item.save!
      message = "#{item_name}を採取した！"
    else
      message = "採取を試みたが、何も見つからなかった。"
    end

    player.save!
    Result.new(status: :ok, message: message, battle: battle)
  end

  def self.rest_encounter!(player)
    danger = (player.location&.danger_level || 0).to_i
    return Result.new(status: :none) if danger <= 0
    return Result.new(status: :none) unless rand(100) < (danger / 3)

    mobs = encounter_mobs_for(player.location)
    return Result.new(status: :none) if mobs.empty?

    player.rests.destroy_all
    battle = create_battle!(player, mobs)
    Result.new(status: :encounter, message: "休憩中に#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に見つかった！", battle: battle)
  end

  def self.item_use_surprise_encounter!(player)
    return Result.new(status: :none) if player.location&.safe_area?
    return Result.new(status: :none) unless rand(100) < 40

    mobs = encounter_mobs_for(player.location)
    return Result.new(status: :none) if mobs.empty?

    battle = create_battle!(player, mobs)
    Result.new(status: :encounter, message: "#{battle.alive_enemies.map { |enemy| enemy.mob.name }.join('、')}に見つかった！", battle: battle)
  end

  def self.create_battle!(player, mobs)
    mobs = Array(mobs).compact
    first_mob = mobs.first
    return unless first_mob

    player.battles.destroy_all
    battle = Battle.create!(player: player, mob: first_mob, enemy_hp: first_mob.hp)
    mobs.first(5).each.with_index(1) do |mob, position|
      battle.battle_enemies.create!(mob: mob, enemy_hp: mob.hp, position: position)
    end
    battle
  end

  def self.encounter_mobs_for(location)
    count = encounter_count_for(location)
    Array.new(count) { weighted_encounter_mob_for(location) }.compact
  end

  def self.weighted_encounter_mob_for(location)
    entries = encounter_entries_for(location)
    return Mob.order("RANDOM()").first if entries.empty?

    total_weight = entries.sum { |entry| entry[:weight] }
    roll = rand(total_weight)
    entries.each do |entry|
      roll -= entry[:weight]
      return entry[:mob] if roll < 0
    end
    entries.last[:mob]
  end

  def self.encounter_entries_for(location)
    location_name = location&.name.to_s
    rows = mob_spawn_rows.select { |row| row["location"] == location_name }
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

  def self.encounter_count_for(location)
    roll = rand(100)
    if location&.name == "はじまりの草原"
      return 5 if roll < 1
      return 4 if roll < 3
      return 3 if roll < 10
      return 2 if roll < 30
      1
    else
      danger = (location&.danger_level || 30).to_i
      return 5 if roll < danger - 35
      return 4 if roll < danger - 20
      return 3 if roll < danger
      return 2 if roll < danger + 25
      1
    end
  end

  def self.gather_encounter_chance(location)
    [[(location&.danger_level || 0).to_i / 2, 10].max, 45].min
  end

  def self.gatherable_items_for(location)
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
