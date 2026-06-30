module Game
  module NpcActions
    def talk_to_npc
      player = current_player
      npc = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)
      unless npc_operable?(player, npc, discovery)
        redirect_to game_path, alert: "#{npc.name}には今は話しかけられません。"
        return
      end

      if discovery.acquainted?
        redirect_to game_path(panel: "npc_menu", npc_id: npc.id)
      else
        first_line = npc.npc_dialogues.active.intro.first
        if first_line
          redirect_to game_path(panel: "npc", npc_id: npc.id, seq: first_line.sequence)
        else
          discovery.become_acquainted!
          affinity_result = NpcAffinityService.gain!(player, npc, action_type: "first_talk")
          redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: npc_affinity_notice("#{npc.name}と顔見知りになった！", affinity_result)
        end
      end
    end

    def npc_next_dialogue
      player = current_player
      npc = Npc.find_by(id: params[:npc_id])
      current_seq = params[:seq].to_i

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)
      unless npc_operable?(player, npc, discovery)
        redirect_to game_path, alert: "#{npc.name}には今は話しかけられません。"
        return
      end

      next_line = npc.npc_dialogues.active
                     .where(dialogue_type: "intro")
                     .where("sequence > ?", current_seq)
                     .order(:sequence)
                     .first

      if next_line
        redirect_to game_path(panel: "npc", npc_id: npc.id, seq: next_line.sequence)
      else
        discovery.become_acquainted!
        affinity_result = NpcAffinityService.gain!(player, npc, action_type: "first_talk")
        redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: npc_affinity_notice("#{npc.name}と顔見知りになった！", affinity_result)
      end
    end

    def npc_gossip
      player = current_player
      npc = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)
      unless npc_operable?(player, npc, discovery)
        redirect_to game_path, alert: "#{npc.name}には今は話しかけられません。"
        return
      end

      affinity_result = NpcAffinityService.gain!(player, npc, action_type: "chat")
      trigger_msg = affinity_result.ok? ? NpcQuestService.check_affinity_triggers!(player, npc, affinity_result.affinity) : ""
      line = npc.npc_dialogues.active.gossip.sample
      message = line ? "#{npc.name}「#{line.text}」" : "#{npc.name}は特に話すことがないようだ。"
      message = npc_affinity_notice(message, affinity_result)
      message += trigger_msg if trigger_msg.present?
      discovery.mark_spoken!
      redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: message
    end

    def npc_info
      player = current_player
      npc = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)
      unless npc_operable?(player, npc, discovery)
        redirect_to game_path, alert: "#{npc.name}には今は話しかけられません。"
        return
      end

      affinity_result = NpcAffinityService.gain!(player, npc, action_type: "info")
      trigger_msg = affinity_result.ok? ? NpcQuestService.check_affinity_triggers!(player, npc, affinity_result.affinity) : ""
      lines = npc.npc_dialogues.active.info
      message = if lines.any?
        lines.map { |line| "#{npc.name}「#{line.text}」" }.join(" / ")
      else
        "#{npc.name}は特に情報を持っていないようだ。"
      end
      message = npc_affinity_notice(message, affinity_result)
      message += trigger_msg if trigger_msg.present?
      discovery.mark_spoken!
      redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: message
    end

    def npc_gift
      player = current_player
      npc = Npc.find_by(id: params[:npc_id])
      item_name = params[:item_name].to_s

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)
      unless npc_operable?(player, npc, discovery)
        redirect_to game_path, alert: "#{npc.name}には今は話しかけられません。"
        return
      end

      result = NpcAffinityService.gift!(player, npc, item_name)
      trigger_msg = result.ok? ? NpcQuestService.check_affinity_triggers!(player, npc, result.affinity) : ""
      discovery.mark_spoken! if result.ok?
      message = result.message.to_s + trigger_msg.to_s
      redirect_to game_path(panel: "npc_menu", npc_id: npc.id), flash_for(NpcQuestService::Result.new(status: result.status == :error ? :error : :ok, message: message))
    end

    def npc_accept_quest
      player = current_player
      quest = NpcQuest.find_by(id: params[:npc_quest_id])

      unless quest
        redirect_to game_path, alert: "そのクエストは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: quest.npc)
      unless npc_operable?(player, quest.npc, discovery)
        redirect_to game_path, alert: "#{quest.npc.name}には今は話しかけられません。"
        return
      end

      result = NpcQuestService.accept_quest!(player, quest)
      discovery.mark_spoken! if result.status == :ok
      redirect_to game_path(panel: "npc_quests", npc_id: quest.npc_id), flash_for(result)
    end

    def npc_complete_quest
      player = current_player
      quest = NpcQuest.find_by(id: params[:npc_quest_id])

      unless quest
        redirect_to game_path, alert: "そのクエストは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: quest.npc)
      unless npc_operable?(player, quest.npc, discovery)
        redirect_to game_path, alert: "#{quest.npc.name}には今は話しかけられません。"
        return
      end

      result = NpcQuestService.complete_quest!(player, quest)
      discovery.mark_spoken! if result.status == :ok
      redirect_to game_path(panel: "npc_quests", npc_id: quest.npc_id), flash_for(result)
    end

    private

    def npc_affinity_notice(message, affinity_result)
      return message unless affinity_result&.message.present?

      "#{message} #{affinity_result.message}"
    end

    def npc_operable?(player, npc, discovery)
      discovery&.talkable? && npc_reachable_by_player?(player, npc)
    end

    def npc_reachable_by_player?(player, npc)
      return false unless player && npc&.active?

      case npc.placement_type
      when "town", "facility"
        player.field_route.blank? &&
          player.location&.safe_area? &&
          player.location_id.present? &&
          player.location_id == npc.location_id
      when "field_area"
        FieldService.current_area_for(player)&.id == npc.field_area_id
      else
        false
      end
    end
  end
end
