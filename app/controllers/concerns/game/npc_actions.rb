module Game
  module NpcActions
    # ─── 会話 ────────────────────────────────────────────────────

    def talk_to_npc
      player = current_player
      npc    = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      discovery = player.npc_discoveries.find_by(npc: npc)

      unless discovery&.talkable?
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
          redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: "#{npc.name}と顔見知りになった！"
        end
      end
    end

    def npc_next_dialogue
      player      = current_player
      npc         = Npc.find_by(id: params[:npc_id])
      current_seq = params[:seq].to_i

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
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
        discovery = player.npc_discoveries.find_by(npc: npc)
        discovery&.become_acquainted!
        redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: "#{npc.name}と顔見知りになった！"
      end
    end

    def npc_gossip
      player = current_player
      npc    = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      new_affinity = player.npc_discoveries.find_by(npc: npc)&.increment_affinity!(1).to_i
      trigger_msg  = NpcQuestService.check_affinity_triggers!(player, npc, new_affinity)

      line    = npc.npc_dialogues.active.gossip.sample
      message = line ? "#{npc.name}「#{line.text}」" : "#{npc.name}は特に話すことがないようだ。"
      message += trigger_msg if trigger_msg.present?
      redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: message
    end

    def npc_info
      player = current_player
      npc    = Npc.find_by(id: params[:npc_id])

      unless npc
        redirect_to game_path, alert: "そのNPCは存在しません。"
        return
      end

      new_affinity = player.npc_discoveries.find_by(npc: npc)&.increment_affinity!(1).to_i
      trigger_msg  = NpcQuestService.check_affinity_triggers!(player, npc, new_affinity)

      lines   = npc.npc_dialogues.active.info
      message = if lines.any?
        lines.map { |l| "#{npc.name}「#{l.text}」" }.join(" / ")
      else
        "#{npc.name}は特に情報を持っていないようだ。"
      end
      message += trigger_msg if trigger_msg.present?
      redirect_to game_path(panel: "npc_menu", npc_id: npc.id), notice: message
    end

    # ─── クエスト ────────────────────────────────────────────────

    def npc_accept_quest
      player = current_player
      quest  = NpcQuest.find_by(id: params[:npc_quest_id])

      unless quest
        redirect_to game_path, alert: "そのクエストは存在しません。"
        return
      end

      result = NpcQuestService.accept_quest!(player, quest)
      redirect_to game_path(panel: "npc_quests", npc_id: quest.npc_id), flash_for(result)
    end

    def npc_complete_quest
      player = current_player
      quest  = NpcQuest.find_by(id: params[:npc_quest_id])

      unless quest
        redirect_to game_path, alert: "そのクエストは存在しません。"
        return
      end

      result = NpcQuestService.complete_quest!(player, quest)
      redirect_to game_path(panel: "npc_quests", npc_id: quest.npc_id), flash_for(result)
    end
  end
end
