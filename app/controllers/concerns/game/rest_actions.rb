module Game
  module RestActions
    REST_SLEEP_TICK_MINUTES = 5
    REST_SLEEP_MAX_TICKS = 288
    INN_SLEEP_HP_RECOVERY_RATE = 0.02
    INN_SLEEP_STATUS_RECOVERY = 2

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

      unless FieldService.field_rest_available?(player)
        redirect_to game_path, notice: "休憩には持ち運びテントが必要です。"
        return
      end

      current_player.rests.destroy_all
      Rest.create!(player: player)
      redirect_to game_path, notice: "休憩を開始した。"
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

    def sleep_rest
      player = current_player
      rest = current_rest

      unless rest
        redirect_to game_path, alert: "休憩中ではありません。"
        return
      end

      ticks = rest_sleep_ticks_for(player)
      elapsed_minutes = 0
      hp_before = player.hp.to_i
      StatusEffectService.activate!(player, "sleep")

      ticks.times do
        player.advance_time!(REST_SLEEP_TICK_MINUTES)
        recover_rest_tick!(player)
        player.save!
        elapsed_minutes += REST_SLEEP_TICK_MINUTES

        check_rest_encounter!(player)
        return if performed?

        break if rest_recovery_complete?(player) && requested_rest_sleep_minutes <= 0
      end

      StatusEffectService.cure!(player, "sleep") if rest_recovery_complete?(player)
      player.increment_skill_counter!("field_sleep_count")
      player.save!

      hp_recovered = player.hp.to_i - hp_before
      message = "眠って#{elapsed_minutes}分経過した。"
      message += "HPが#{hp_recovered}回復した。" if hp_recovered.positive?
      message += "状態異常値が少し回復した。"
      redirect_to game_path, notice: message
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

      requested_minutes = requested_inn_sleep_minutes(player)
      if rest_recovery_complete?(player) && requested_minutes <= 0
        redirect_to game_path(panel: "inn"), alert: "HPと状態異常値は回復済みです。眠る時間を5分以上で入力してください。"
        return
      end

      current_player.rests.destroy_all
      player.col = player.col.to_i - cost
      ticks = inn_sleep_ticks_for(player, requested_minutes)
      elapsed_minutes = 0
      hp_before = player.hp.to_i
      status_before = StatusEffectService.recoverable_value_total(player)

      ticks.times do
        advance_inn_sleep_time!(player, REST_SLEEP_TICK_MINUTES)
        recover_inn_sleep_tick!(player)
        elapsed_minutes += REST_SLEEP_TICK_MINUTES

        break if requested_minutes <= 0 && rest_recovery_complete?(player)
      end

      StatusEffectService.cure_recoverable!(player) if rest_recovery_complete?(player)
      player.reset_sleep_deprivation!
      player.save!

      payment_message = cost.positive? ? "#{cost}コル支払った。" : ""
      hp_recovered = player.hp.to_i - hp_before
      status_recovered = [status_before - StatusEffectService.recoverable_value_total(player), 0].max
      recovery_message = []
      recovery_message << "HPが#{hp_recovered}回復した" if hp_recovered.positive?
      recovery_message << "状態異常値が#{status_recovered.round(2)}回復した" if status_recovered.positive?
      recovery_message = recovery_message.present? ? "#{recovery_message.join('、')}。" : ""
      redirect_to game_path(panel: "inn"), notice: "宿屋で眠った。#{payment_message}#{elapsed_minutes}分経過した。#{recovery_message}"
    end

    private

    def rest_sleep_ticks_for(player)
      requested_minutes = requested_rest_sleep_minutes
      return (requested_minutes / REST_SLEEP_TICK_MINUTES.to_f).ceil.clamp(1, REST_SLEEP_MAX_TICKS) if requested_minutes.positive?

      missing_hp = [player.effective_max_hp - player.hp.to_i, 0].max
      status_total = StatusEffectService.recoverable_value_total(player)
      hp_ticks = (missing_hp.to_f / [(player.effective_max_hp * 0.01).ceil, 1].max).ceil
      status_ticks = status_total.positive? ? REST_SLEEP_MAX_TICKS : 0
      [hp_ticks, status_ticks, 1].max.clamp(1, REST_SLEEP_MAX_TICKS)
    end

    def requested_rest_sleep_minutes
      minutes = params[:sleep_minutes].to_i
      return 0 if minutes <= 0

      (minutes / REST_SLEEP_TICK_MINUTES.to_f).ceil * REST_SLEEP_TICK_MINUTES
    end

    def requested_inn_sleep_minutes(player)
      if params.key?(:wake_hour) || params.key?(:wake_minute)
        wake_hour = params[:wake_hour].to_i.clamp(0, 23)
        wake_minute = params[:wake_minute].to_i.clamp(0, 59)
        current_minutes = player.current_time.to_i % 1440
        wake_minutes = wake_hour * 60 + wake_minute
        minutes_until_wake = (wake_minutes - current_minutes) % 1440
        minutes_until_wake = 1440 if minutes_until_wake.zero?

        return (minutes_until_wake / REST_SLEEP_TICK_MINUTES.to_f).ceil * REST_SLEEP_TICK_MINUTES
      end

      minutes = params[:sleep_minutes].to_i
      minutes += params[:sleep_hours].to_i * 60 if params.key?(:sleep_hours)
      return 0 if minutes <= 0

      (minutes / REST_SLEEP_TICK_MINUTES.to_f).ceil * REST_SLEEP_TICK_MINUTES
    end

    def recover_rest_tick!(player)
      hp_recover = [(player.effective_max_hp * 0.01).ceil, 1].max
      player.hp = [player.hp.to_i + hp_recover, player.effective_max_hp].min
      StatusEffectService.rest_recover_values!(player)
    end

    def rest_recovery_complete?(player)
      player.hp.to_i >= player.effective_max_hp &&
        StatusEffectService.recoverable_value_total(player) <= 0
    end

    def inn_sleep_ticks_for(player, requested_minutes)
      return (requested_minutes / REST_SLEEP_TICK_MINUTES.to_f).ceil.clamp(1, REST_SLEEP_MAX_TICKS) if requested_minutes.positive?

      missing_hp = [player.effective_max_hp - player.hp.to_i, 0].max
      hp_recovery = [(player.effective_max_hp * INN_SLEEP_HP_RECOVERY_RATE).ceil, 1].max
      hp_ticks = (missing_hp.to_f / hp_recovery).ceil
      status_ticks = (StatusEffectService.recoverable_value_total(player) / INN_SLEEP_STATUS_RECOVERY).ceil
      [hp_ticks, status_ticks, 1].max.clamp(1, REST_SLEEP_MAX_TICKS)
    end

    def advance_inn_sleep_time!(player, minutes)
      player.decrease_satiety!(minutes)
      total = player.current_time.to_i + minutes.to_i
      days = total / 1440
      player.current_time = total % 1440
      days.times { player.advance_day! }
    end

    def recover_inn_sleep_tick!(player)
      hp_recover = [(player.effective_max_hp * INN_SLEEP_HP_RECOVERY_RATE).ceil, 1].max
      player.hp = [player.hp.to_i + hp_recover, player.effective_max_hp].min
      StatusEffectService.recover_values_by!(player, INN_SLEEP_STATUS_RECOVERY)
    end
  end
end


