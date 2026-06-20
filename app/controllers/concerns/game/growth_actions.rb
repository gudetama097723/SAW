module Game
  module GrowthActions
    def allocate_strength
      redirect_to game_path(panel: "growth", strength_points: 1, agility_points: 0)
    end

    def allocate_agility
      redirect_to game_path(panel: "growth", strength_points: 0, agility_points: 1)
    end

    def allocate_stats
      player = current_player
      available_points = [player.stat_points.to_i, 3].min
      strength_points = params[:strength_points].to_i
      agility_points = params[:agility_points].to_i
      total_points = strength_points + agility_points

      if available_points <= 0
        redirect_to game_path(panel: "growth"), alert: "振り分けポイントがありません。"
        return
      end

      if strength_points.negative? || agility_points.negative? || total_points != available_points
        redirect_to game_path(panel: "growth", strength_points: strength_points, agility_points: agility_points), alert: "#{available_points}ポイントをすべて振り分けてください。"
        return
      end

      player.skip_stat_allocate_confirm = true if params[:skip_confirm] == "1"
      player.strength = player.strength.to_i + strength_points
      player.agility = player.agility.to_i + agility_points
      player.stat_points = player.stat_points.to_i - total_points
      player.save!

      redirect_to game_path(panel: "growth"), notice: "筋力に#{strength_points}、敏捷に#{agility_points}ポイント振り分けた。"
    end
  end
end
