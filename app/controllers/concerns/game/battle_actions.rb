module Game
  module BattleActions
  def learn_skill
    definition = SkillUnlockService.available_for(current_player).find { |candidate| candidate.name == params[:skill_name] }
    unless definition
      redirect_to game_path(panel: "growth"), alert: "そのスキルはまだ習得できません。"
      return
    end

    if current_player.remaining_skill_slots <= 0
      redirect_to game_path(panel: "growth"), alert: "スキルスロットが足りません。"
      return
    end

    current_player.skills.create!(name: definition.name, proficiency: 0, skill_exp: 0, skill_category: definition.skill_category, weapon_skill: definition.weapon_skill)
    redirect_to game_path(panel: "growth"), notice: "#{definition.name}を習得した。"
  end

  def attack

      result = BattleService.resolve_player_attack!(
        battle: current_battle,
        player: current_player,
        mob_part_id: params[:mob_part_id],
        target_enemy_id: params[:target_enemy_id],
        label: "通常攻撃",
        damage_multiplier: 100,
        durability_cost: 1,
        skill_gain: 0,
        stiffness: false,
        hits: 1,
        sword_skill: false,
        attack_attribute: params[:attack_attribute]
      )
      redirect_with_result(result, battle_command: "attack", attack_group: params[:attack_group], target_enemy_id: params[:target_enemy_id], attack_attribute: params[:attack_attribute])
    end

    def sword_skill
      player = current_player
      weapon = player.equipped_weapon
      skill_set = BattleService.weapon_skill_name(weapon)
      skill_key = params[:skill].presence || SkillCatalog.first_for(skill_set)&.key || "vertical"
      sword_skill = player.skills.find_by(name: skill_set)
      proficiency = sword_skill&.proficiency.to_i
      skill_config = sword_skill_config(skill_key)

      unless skill_config[:skill_set] == skill_set && proficiency >= skill_config[:required]
        redirect_to game_path(battle_command: "sword_skill", selected_skill: skill_key), alert: "#{skill_config[:label]}はまだ習得していません。"
        return
      end

      result = BattleService.resolve_player_attack!(
        battle: current_battle,
        player: player,
        mob_part_id: params[:mob_part_id],
        target_enemy_id: params[:target_enemy_id],
        group_start: params[:group_start],
        label: skill_config[:label],
        damage_multiplier: skill_config[:damage_multiplier],
        durability_cost: skill_config[:durability_cost],
        skill_gain: skill_config[:skill_gain],
        stiffness: true,
        hits: skill_config[:hits],
        sword_skill: true,
        area: skill_config[:area],
        attack_attribute: skill_config[:attack_attribute]
      )
      redirect_with_result(
        result,
        battle_command: "sword_skill",
        selected_skill: skill_key,
        target_enemy_id: params[:target_enemy_id],
        group_start: params[:group_start]
      )
    end

    def use_battle_item
      battle = current_battle
      player = current_player

      unless battle
        redirect_to game_path, alert: "戦闘中ではありません。"
        return
      end

      unless params[:item_name].in?(["ポーション", *ItemService::STATUS_CURE_ITEMS.keys])
        redirect_to game_path(battle_command: "item"), alert: "そのアイテムはまだ使用できません。"
        return
      end

      item_result = params[:item_name] == "ポーション" ? ItemService.consume_healing_potion!(player) : ItemService.consume_status_cure!(player, params[:item_name])
      unless item_result.status == :ok
        redirect_to game_path(battle_command: "item"), alert: item_result.message
        return
      end

      enemy_result = BattleService.apply_enemy_attack!(player, battle)

      if enemy_result.status == :defeated
        redirect_to game_path(panel: "inn"), alert: "#{item_result.message}#{enemy_result.message}"
      else
        redirect_to game_path(battle_command: "item"), notice: "#{item_result.message}#{enemy_result.message}"
      end
    end

    def use_item
      player = current_player

      if current_player.battles.exists?
        redirect_to game_path(battle_command: "item"), alert: "戦闘中は戦闘コマンドからアイテムを使ってください。"
        return
      end

      unless params[:item_name].in?(["ポーション", *ItemService::STATUS_CURE_ITEMS.keys])
        redirect_to game_path(panel: "items", item_category: "healing"), alert: "そのアイテムはまだ使用できません。"
        return
      end

      item_result = params[:item_name] == "ポーション" ? ItemService.consume_healing_potion!(player) : ItemService.consume_status_cure!(player, params[:item_name])
      unless item_result.status == :ok
        redirect_to game_path(panel: "items", item_category: "healing"), alert: item_result.message
        return
      end

      player.advance_time!(10)
      player.save!

      surprise_message = check_item_use_surprise_encounter!(player)
      return if performed?

      redirect_to game_path(panel: "items", item_category: "healing"), notice: "#{item_result.message}#{surprise_message}"
    end

    def eat_item
      player = current_player
      item = player.items.find_by(id: params[:item_id]) || player.items.find_by(name: params[:item_name])
      item_category = item&.category || params[:item_category].presence || "gathered"

      if current_player.battles.exists?
        redirect_to game_path(battle_command: "item"), alert: "戦闘中は食べられません。"
        return
      end

      item_result = ItemService.eat_item!(player, item)
      unless item_result.status == :ok
        redirect_to game_path(panel: "items", item_category: item_category), alert: item_result.message
        return
      end

      surprise_message = check_item_use_surprise_encounter!(player)
      return if performed?

      redirect_to game_path(panel: "items", item_category: item_category), notice: "#{item_result.message}#{surprise_message}"
    end

    def escape
      battle = current_battle
      player = current_player

      unless battle
        redirect_to game_path, alert: "戦闘中ではありません。"
        return
      end

      BattleService.ensure_battle_enemies!(battle)
      alive_enemies = battle.alive_enemies.to_a
      enemy_agility = alive_enemies.map { |battle_enemy| BattleService.mob_effective_agility(battle_enemy) }.max.to_i
      agility_gap = player.effective_agility - enemy_agility
      enemy_count_penalty = [alive_enemies.size - 1, 0].max * 12
      chance = [[50 + agility_gap * 10 - enemy_count_penalty, 5].max, 95].min
      if rand(100) < chance
        BuffEffectService.clear_battle_effects!(player)
        player.save!
        battle.destroy
        redirect_to game_path, notice: "逃走に成功した。"
      else
        enemy_result = BattleService.apply_enemy_attack!(player, battle)

        if enemy_result.status == :defeated
          redirect_to game_path(panel: "inn"), alert: "逃走に失敗した。#{enemy_result.message}"
        else
          redirect_to game_path(battle_command: params[:battle_command].presence), alert: "逃走に失敗した。#{enemy_result.message}"
        end
      end
    end
  end
end
