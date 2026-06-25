module Game
  module FieldActions
    def stroll
      player = current_player

      unless player.location&.safe_area?
        redirect_to game_path, alert: "ここは安全地帯ではありません。"
        return
      end

      result = rand(100)
      player.advance_time!(10)
      discovery = player.town_discovery_for
      npc_discovery = NpcDiscoveryService.discover_during_stroll!(player)

      if !discovery.found_inn? && result < 30
        discovery.found_inn = true
        ActiveRecord::Base.transaction { discovery.save!; player.save! }
        redirect_to game_path, notice: append_npc_discovery_message("広場の近くで宿屋を見つけた！", npc_discovery)
      elsif !discovery.found_item_shop? && result < 60
        discovery.found_item_shop = true
        ActiveRecord::Base.transaction { discovery.save!; player.save! }
        redirect_to game_path, notice: append_npc_discovery_message("街を散策していると、道具屋を見つけた！", npc_discovery)
      elsif !discovery.found_blacksmith? && result < 85
        discovery.found_blacksmith = true
        ActiveRecord::Base.transaction { discovery.save!; player.save! }
        redirect_to game_path, notice: append_npc_discovery_message("路地裏で鍛冶屋を見つけた！", npc_discovery)
      elsif discovery.has_attribute?(:found_restaurant) && !discovery.found_restaurant? && result < 95
        discovery.found_restaurant = true
        ActiveRecord::Base.transaction { discovery.save!; player.save! }
        redirect_to game_path, notice: append_npc_discovery_message("漂ってきた香りをたどって、飲食店を見つけた！", npc_discovery)
      else
        player.save!
        message = npc_discovery.discovered? ? "街を散策した。" : "街を散策した。特に新しい発見はなかった。"
        redirect_to game_path, notice: append_npc_discovery_message(message, npc_discovery)
      end
    end

    def explore
      result = FieldService.explore!(current_player)
      redirect_with_result(result)
    end

    def gather
      result = FieldService.gather!(current_player)
      redirect_with_result(result)
    end

    def hunt
      result = FieldService.hunt!(current_player)
      redirect_to game_path, notice: result.message
    end

    def open_treasure
      treasure = TreasureChest.find_by(id: params[:treasure_chest_id])
      result = treasure ? ExplorationRewardService.open_treasure!(current_player, treasure) : ExplorationRewardService::Result.new(status: :error, message: "その宝箱は存在しません。")
      redirect_with_result(result)
    end

  def inspect_treasure
    treasure = TreasureChest.find_by(id: params[:treasure_chest_id])
    result = treasure ? ExplorationRewardService.inspect_treasure!(current_player, treasure) : ExplorationRewardService::Result.new(status: :error, message: "その宝箱は見つかりません。")
    redirect_with_result(result)
  end

  def ignore_treasure
    treasure = TreasureChest.find_by(id: params[:treasure_chest_id])
    result = treasure ? ExplorationRewardService.ignore_treasure!(current_player, treasure) : ExplorationRewardService::Result.new(status: :error, message: "その宝箱は見つかりません。")
    redirect_with_result(result)
  end

  def challenge_boss

      mob = Mob.find_by(id: params[:mob_id])
      result = mob ? ExplorationRewardService.start_boss_battle!(current_player, mob) : ExplorationRewardService::Result.new(status: :error, message: "そのボスは存在しません。")
      redirect_with_result(result, battle_command: "attack")
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

      interruption = FieldService.field_status_interruption!(player)
      if interruption
        redirect_with_result(interruption)
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

        player.advance_time!(5)
        player.save!

        redirect_to game_path, notice: "#{route.name}に出た。"
        return
      end

      # すでにフィールド上にいる場合：フィールド内を進む
      unless player.field_route == route
        redirect_to game_path, notice: "現在進行中のフィールド以外には移動できない。"
        return
      end

      advance = [(rand(15..25) * player.movement_speed_multiplier).round, 1].max
      current_area = FieldService.current_area_for(player)
      current_area_progress = player.progress_for_area(current_area)
      direction = params[:direction]
      reached_destination = FieldService.destination_reached?(player, route)

      if direction == "backward" && player.field_position.to_i <= 0
        player.location = route.from_location
        player.field_route = nil
        player.field_position = 0
        player.advance_time!(5)
        player.save!
        redirect_to game_path, notice: "#{route.from_location.name}へ戻った。5分経過した。"
        return
      end

      if direction == "area"
        target_area = FieldService.next_discovered_area_for(player, route)
        unless target_area
          redirect_to game_path, notice: "進める探索済みエリアはまだ見つかっていない。"
          return
        end

        next_position = target_area.start_distance
      else
        next_position =
          if direction == "backward"
            player.field_position.to_i - advance
          else
            player.field_position.to_i + advance
          end
      end

      if direction != "backward" &&
        direction != "area" &&
        current_area &&
        next_position > current_area.end_distance.to_i &&
        current_area_progress.mapping_progress.to_i < current_area.required_mapping_to_enter_next.to_i
        redirect_to game_path, notice: "#{current_area.name}の地形把握が足りず、先へ進めない。探索で踏破度を上げよう。"
        return
      end

      player.field_position = next_position

      direction_text =
        if direction == "backward"
          route.from_location.name
        elsif direction == "area"
          FieldService.current_area_for(player)&.name || "探索済みエリア"
        else
          route.to_location.name
      end

      elapsed_time = rand(10..20)
      player.advance_time!(elapsed_time)

      if player.field_position <= 0
        player.location = route.from_location
        player.field_route = nil
        player.field_position = 0
        player.save!

        redirect_to game_path, notice: "#{route.from_location.name}へ到着した。#{elapsed_time}分経過した。"
        return
      end

      if player.field_position >= route.distance
        unless FieldService.destination_discovered?(player, route)
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

    private

    def append_npc_discovery_message(message, npc_discovery)
      return message unless npc_discovery&.discovered?

      "#{message} #{npc_discovery.message}"
    end
  end
end
