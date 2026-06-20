module Game
  module RestActions
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
        player.advance_time!(10)

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

      player.advance_time!(10)
      player.save!

      check_rest_encounter!(player)
      return if performed?

      redirect_to game_path, notice: item_result.message
    end

    def end_rest
      current_player.rests.destroy_all
      redirect_to game_path, notice: "休憩を終えた。"
    end

    def inn
      player = current_player

      unless player.location&.safe_area?
        redirect_to game_path(panel: "inn"), alert: "宿屋は街で利用できます。"
        return
      end

      unless player.town_discovery_for&.found_inn?
        redirect_to game_path(panel: "inn"), alert: "宿屋はまだ見つけていません。"
        return
      end

      if current_player.battles.exists?
        redirect_to game_path(panel: "inn"), alert: "戦闘中は宿屋を利用できません。"
        return
      end

      base_type = player.location&.name == "ホルンカの村" ? "temporary" : "home"
      current_inn_base = player.player_bases.find_by(location: player.location, base_type: base_type, active: true)
      cost = current_inn_base ? 0 : inn_cost_for(player.location)
      if player.col.to_i < cost
        redirect_to game_path(panel: "inn"), alert: "コルが足りません。宿屋で休むには#{cost}コル必要です。"
        return
      end

      current_player.rests.destroy_all
      player.col = player.col.to_i - cost
      player.hp = player.effective_max_hp
      player.advance_time!(60)
      player.save!

      payment_message = cost.positive? ? "#{cost}コル支払った。" : ""
      redirect_to game_path(panel: "inn"), notice: "宿屋で休憩した。#{payment_message}HPが全快した。"
    end
  end
end


