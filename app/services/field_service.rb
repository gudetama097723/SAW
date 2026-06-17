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
        mob = Mob.order("RANDOM()").first
        battle = create_battle!(player, mob)
        "#{mob.name}と遭遇した！"
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
      mob = Mob.order("RANDOM()").first
      battle = create_battle!(player, mob)
      message = "採取中に#{mob.name}と遭遇した！"
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

    mob = Mob.order("RANDOM()").first
    return Result.new(status: :none) unless mob

    Rest.destroy_all
    battle = create_battle!(player, mob)
    Result.new(status: :encounter, message: "休憩中に#{mob.name}に見つかった！", battle: battle)
  end

  def self.item_use_surprise_encounter!(player)
    return Result.new(status: :none) if player.location&.safe_area?
    return Result.new(status: :none) unless rand(100) < 40

    mob = Mob.order("RANDOM()").first
    return Result.new(status: :none) unless mob

    battle = create_battle!(player, mob)
    Result.new(status: :encounter, message: "#{mob.name}に見つかった！", battle: battle)
  end

  def self.create_battle!(player, mob)
    Battle.destroy_all
    Battle.create!(player: player, mob: mob, enemy_hp: mob.hp)
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
