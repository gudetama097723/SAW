class GameController < ApplicationController
  include Game::FieldActions
  include Game::BattleActions
  include Game::RestActions
  include Game::ShopActions
  include Game::BaseActions
  include Game::GrowthActions
  include Game::NpcActions
  before_action :require_login

  def index
    @player = current_player
    @battle = current_battle
    @rest = current_rest
    @routes = FieldService.available_routes_for(@player)
    @current_field_area = FieldService.current_area_for(@player)
    @environment_location = @player.field_route.present? ? FieldService.environment_location_for(@player) : @player.location
    @current_field_area_progress = @player.progress_for_area(@current_field_area)
    @available_treasures = ExplorationRewardService.discovered_treasures(@player)
    @available_bosses = ExplorationRewardService.discovered_bosses(@player)
    @town_discovery = @player.town_discovery_for if @player.location&.safe_area?
    current_panel = params[:panel].presence
    if current_panel.in?(%w[inn item_shop blacksmith restaurant]) &&
       @player.field_route.blank? && @player.location&.safe_area?
      NpcDiscoveryService.discover_during_facility_visit!(@player, current_panel)
    end
    @talkable_npcs = talkable_npcs_for(@player, current_panel)
    @active_player_quests = @player.active_quests.includes(npc_quest: :npc)
    if @battle
      BattleService.ensure_battle_enemies!(@battle)
      @battle_enemies = @battle.alive_enemies.includes(mob: :mob_parts).to_a
      @part_states_by_enemy = @battle_enemies.to_h do |battle_enemy|
        parts = BattleService.ensure_mob_parts!(battle_enemy.mob)
        [battle_enemy.id, BattleService.ensure_part_states!(battle_enemy, parts)]
      end
    end
    @active_route_progress = @player.player_route_progresses.includes(route: [:from_location, :to_location]).first
  end

  private

  def current_battle
    current_player.battles.order(:created_at).last
  end

  def current_rest
    current_player.rests.order(:created_at).last
  end

  def check_rest_encounter!(player)
    result = FieldService.rest_encounter!(player)
    if result.status == :encounter
      redirect_to game_path, alert: result.message
      return ""
    end
  end

  def check_item_use_surprise_encounter!(player)
    encounter = FieldService.item_use_surprise_encounter!(player)
    return "" unless encounter.status == :encounter

    enemy_result = BattleService.apply_enemy_attack!(player, encounter.battle, prefix: "アイテム使用中の不意打ち！")
    if enemy_result.status == :defeated
      redirect_to game_path(panel: "inn"), alert: enemy_result.message
      return ""
    end

    "#{encounter.message}#{enemy_result.message}"
  end

  def redirect_with_result(result, path_options = {})
    path_options.compact!
    if result.status == :error
      redirect_to game_path(path_options), alert: result.message
    elsif result.status == :defeated
      redirect_to game_path(panel: "inn"), alert: result.message
    else
      redirect_to game_path(path_options), notice: result.message
    end
  end

  def sword_skill_config(skill_key)
    skill = SkillCatalog.find(skill_key)
    {
      label: skill.name,
      skill_set: skill.skill_set,
      required: skill.required_proficiency,
      damage_multiplier: skill.damage_multiplier,
      durability_cost: skill.durability_cost,
      skill_gain: skill.skill_gain,
      hits: skill.hits,
      area: skill.area?,
      attack_attribute: skill.attack_attribute
    }
  end

  def flash_for(result)
    result.status == :ok ? { notice: result.message } : { alert: result.message }
  end

  def talkable_npcs_for(player, current_panel = nil)
    if player.field_route.blank? && player.location&.safe_area? && player.location_id.present?
      player.npc_discoveries
            .joins(:npc)
            .where(currently_available: true)
            .where(npcs: { active: true, location_id: player.location_id })
            .where(
              "npcs.placement_type = ? OR (npcs.placement_type = ? AND npcs.facility_key = ?)",
              "town", "facility", current_panel.to_s
            )
            .includes(:npc)
            .map(&:npc)
    elsif @current_field_area.present?
      player.npc_discoveries
            .joins(:npc)
            .where(currently_available: true)
            .where(npcs: { active: true, field_area_id: @current_field_area.id, placement_type: "field_area" })
            .includes(:npc)
            .map(&:npc)
    else
      []
    end
  end

  def inn_cost_for(location)
    case location&.name
    when "ホルンカの村"
      50
    else
      0
    end
  end
end
