module Game
  module ShopActions
    def item_shop
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "item_shop")
        redirect_to game_path, alert: FacilityHoursService.closed_message("item_shop", player)
        return
      end

      item_name = params[:item_name].presence || "ポーション"
      quantity = shop_quantity_param

      unless params[:confirm_purchase] == "1"
        redirect_to game_path(panel: "item_shop", shop_menu: "buy", item_name: item_name, quantity: quantity, confirm_purchase: "1"),
                    alert: "購入内容を確認してください。"
        return
      end

      result = ItemService.buy_shop_item!(player, item_name, quantity: quantity)
      redirect_to game_path(panel: "item_shop", shop_menu: "buy"), flash_for(result)
    end

    def produce_item
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "item_shop")
        redirect_to game_path, alert: FacilityHoursService.closed_message("item_shop", player)
        return
      end

      quantity = shop_quantity_param

      unless params[:confirm_production] == "1"
        redirect_to game_path(panel: "item_shop", shop_menu: "produce", quantity: quantity, confirm_production: "1"),
                    alert: "生産内容を確認してください。"
        return
      end

      result = ItemService.produce_potion!(player, quantity: quantity)
      redirect_to game_path(panel: "item_shop", shop_menu: "produce"), flash_for(result)
    end

    def sell_item
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "item_shop")
        redirect_to game_path, alert: FacilityHoursService.closed_message("item_shop", player)
        return
      end

      item = player.items.find_by(name: params[:item_name])
      if item&.unique_item? && params[:confirm_unique] != "1"
        redirect_to game_path(panel: "item_shop", shop_menu: "sell", confirm_item_id: item.id),
                    alert: "このアイテムは二度と手には入らないかもしれません。本当に売却しますか？"
        return
      end

      quantity = params[:sell_all] == "1" ? item&.quantity.to_i : params[:quantity].to_i
      result = ItemService.sell_item!(player, item, quantity: quantity, confirm_unique: params[:confirm_unique] == "1")
      redirect_to game_path(panel: "item_shop", shop_menu: "sell"), flash_for(result)
    end

    def restaurant
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_restaurant?
        redirect_to game_path, alert: "飲食店はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "restaurant")
        redirect_to game_path, alert: FacilityHoursService.closed_message("restaurant", player)
        return
      end

      menu_name = params[:menu_name].presence
      unless menu_name
        redirect_to game_path(panel: "restaurant"), alert: "料理を選んでください。"
        return
      end

      unless params[:confirm_order] == "1"
        redirect_to game_path(panel: "restaurant", menu_name: menu_name, confirm_order: "1"),
                    alert: "注文内容を確認してください。"
        return
      end

      result = RestaurantService.eat_menu!(player, menu_name)
      redirect_to game_path(panel: "restaurant"), flash_for(result)
    end

  def discard_item
    player = current_player
    item = player.items.find_by(id: params[:item_id]) || player.items.find_by(name: params[:item_name])
    unless item&.quantity.to_i.positive?
      redirect_to game_path(panel: "items"), alert: "そのアイテムは所持していません。"
      return
    end
    unless item.discardable_by_player?
      redirect_to game_path(panel: "items"), alert: "そのアイテムは捨てられません。"
      return
    end

    quantity = params[:quantity].to_i
    quantity = 1 if quantity <= 0
    quantity = [quantity, item.quantity.to_i].min

    item.quantity -= quantity
    item.quantity.to_i <= 0 ? item.destroy! : item.save!

    redirect_to game_path(panel: "items", item_category: item.category), notice: "#{item.name}を#{quantity}個捨てた。"
  end

  def discard_weapon
    weapon = current_player.weapons.find_by(id: params[:weapon_id])
    unless weapon&.discardable_by_player?
      redirect_to game_path(panel: "equipment"), alert: "その武器は捨てられません。"
      return
    end

    name = weapon.name
    weapon.destroy!
    redirect_to game_path(panel: "equipment"), notice: "#{name}を捨てた。"
  end

  def discard_armor
    armor = current_player.armors.find_by(id: params[:armor_id])
    unless armor&.discardable_by_player?
      redirect_to game_path(panel: "equipment"), alert: "その防具は捨てられません。"
      return
    end

    name = armor.name
    armor.destroy!
    redirect_to game_path(panel: "equipment"), notice: "#{name}を捨てた。"
  end

  def toggle_weapon_favorite
    weapon = current_player.weapons.find_by(id: params[:weapon_id])
    unless weapon
      redirect_to game_path(panel: "equipment"), alert: "その武器は所持していません。"
      return
    end

    weapon.update!(favorite: !weapon.favorite?)
    redirect_to game_path(panel: "equipment"), notice: weapon.favorite? ? "#{weapon.name}をお気に入り登録した。" : "#{weapon.name}のお気に入りを解除した。"
  end

  def toggle_armor_favorite
    armor = current_player.armors.find_by(id: params[:armor_id])
    unless armor
      redirect_to game_path(panel: "equipment"), alert: "その防具は所持していません。"
      return
    end

    armor.update!(favorite: !armor.favorite?)
    redirect_to game_path(panel: "equipment"), notice: armor.favorite? ? "#{armor.name}をお気に入り登録した。" : "#{armor.name}のお気に入りを解除した。"
  end

  def upgrade_weapon
    player = current_player

    unless BlacksmithFacilityAccessService.available?(player)
      redirect_to game_path, alert: BlacksmithFacilityAccessService.message_for(:enhance)
      return
    end

    unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
      redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    unless facility_open_for?(player, "blacksmith")
      redirect_to game_path, alert: FacilityHoursService.closed_message("blacksmith", player)
      return
    end

    weapon = player.weapons.find_by(id: params[:weapon_id])
    result = WeaponUpgradeService.upgrade!(player, weapon, params[:enhancement_type], blacksmith_mode: params[:smith_mode])
    redirect_to game_path(panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: weapon&.id, smith_mode: params[:smith_mode]), flash_for(result)
  end

  def evolve_weapon
    player = current_player

    unless BlacksmithFacilityAccessService.available?(player)
      redirect_to game_path, alert: BlacksmithFacilityAccessService.message_for(:evolve)
      return
    end

    unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
      redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
      return
    end

    unless facility_open_for?(player, "blacksmith")
      redirect_to game_path, alert: FacilityHoursService.closed_message("blacksmith", player)
      return
    end

    weapon = player.weapons.find_by(id: params[:weapon_id])
    rule = WeaponEvolutionRule.find_by(source_weapon_name: weapon&.name)
    if !weapon || !rule
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve"), alert: "進化できる武器ではありません。"
      return
    end
    unless weapon.enhancement_level >= rule.required_enhancement_level.to_i
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", weapon_id: weapon.id), alert: "+#{rule.required_enhancement_level}まで強化した武器のみ進化できます。"
      return
    end
    if current_player.level.to_i < rule.required_player_level.to_i
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", weapon_id: weapon.id), alert: "鍛冶屋「お前にはまだ早い」"
      return
    end

    weapon.update!(
      name: rule.target_weapon_name,
      enhancement_level: 0,
      enhance_attempts: 0,
      sharpness_level: 0,
      quickness_level: 0,
      accuracy_level: 0,
      heaviness_level: 0,
      durability_level: 0,
      durability_loss_remainder: 0,
      durability: [ weapon.durability.to_i, weapon.max_durability.to_i ].min
    )
    redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve"), notice: "#{rule.target_weapon_name}へ進化した。"
  end

    def blacksmith
      player = current_player
      self_maintenance = params[:smith_mode].to_s == "player"

      unless self_maintenance
        unless BlacksmithFacilityAccessService.available?(player)
          redirect_to game_path, alert: BlacksmithFacilityAccessService.message_for(:npc_maintenance)
          return
        end

        unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
          redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
          return
        end

        unless facility_open_for?(player, "blacksmith")
          redirect_to game_path, alert: FacilityHoursService.closed_message("blacksmith", player)
          return
        end
      end

      if params[:repair_all] == "1" && !self_maintenance
        unless params[:confirm_repair] == "1"
          redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc"), alert: "整備する内容を確認してください。"
          return
        end

        context = BlacksmithService.context_for(player, mode: "npc")
        weapons = player.weapons.select do |weapon|
          weapon.durability.to_i < weapon.effective_max_durability &&
            context && context.proficiency >= weapon.maintenance_level.to_i
        end
        armors = player.armors.select { |armor| armor.repair_cost.positive? }
        equipment = weapons + armors
        if equipment.empty?
          redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc"), alert: "整備できる装備がありません。"
          return
        end

        weapon_fees = weapons.sum { |weapon| (weapon.repair_cost * context.fee_multiplier(:maintenance)).round }
        armor_fees = armors.sum { |armor| (armor.repair_cost * context.fee_multiplier(:maintenance)).round }
        total_fee = weapon_fees + armor_fees
        if player.col.to_i < total_fee
          redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc"), alert: "コルが足りません。整備には#{total_fee}コル必要です。"
          return
        end

        ActiveRecord::Base.transaction do
          player.lock!
          weapons.each(&:lock!)
          armors.each(&:lock!)
          player.col = player.col.to_i - total_fee
          player.advance_time!(20 * equipment.size)
          weapons.each { |weapon| weapon.update!(durability: weapon.effective_max_durability) }
          armors.each { |armor| armor.update!(durability: armor.max_durability) }
          player.save!
        end

        repaired_names = equipment.map { |item| item.respond_to?(:display_name) ? item.display_name : item.name }.join("、")
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: "npc"), notice: "鍛冶屋で#{repaired_names}をまとめて整備した。#{total_fee}コル支払った。"
        return
      end

      if params[:armor_id].present? && params[:smith_mode].to_s != "player"
        armor = player.armors.find_by(id: params[:armor_id])
        unless armor&.repair_cost.to_i&.positive?
          redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), alert: "整備できる防具がありません。"
          return
        end
        context = BlacksmithService.context_for(player, mode: "npc")
        fee = context ? (armor.repair_cost * context.fee_multiplier(:maintenance)).round : armor.repair_cost
        if player.col.to_i < fee
          redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), alert: "コルが足りません。整備には#{fee}コル必要です。"
          return
        end
        ActiveRecord::Base.transaction do
          player.update!(col: player.col.to_i - fee)
          armor.update!(durability: armor.max_durability)
        end
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), notice: "鍛冶屋で#{armor.name}を整備した。#{fee}コル支払った。"
        return
      end

      weapon = player.weapons.find_by(id: params[:weapon_id])
      context = BlacksmithService.context_for(player, mode: params[:smith_mode])
      result = WeaponMaintenanceService.call(player: player, weapon: weapon, blacksmith: context)
      destination = self_maintenance ? game_path(panel: "equipment") : game_path(panel: "blacksmith", blacksmith_menu: "repair", smith_mode: params[:smith_mode])
      redirect_to destination, flash_for(result)
    end

    def weapon_shop
      player = current_player
      unless player.location&.safe_area? && player.town_discovery_for&.found_weapon_shop?
        redirect_to game_path, alert: "武具店はまだ利用できません。"
        return
      end
      unless facility_open_for?(player, "weapon_shop")
        redirect_to game_path, alert: FacilityHoursService.closed_message("weapon_shop", player)
        return
      end

      kind = params[:equipment_type].to_s
      definition = kind == "armor" ? ShopCatalog.weapon_shop_armor(player.location, params[:equipment_name]) : ShopCatalog.weapon_shop_weapon(player.location, params[:equipment_name])
      unless definition
        redirect_to game_path(panel: "weapon_shop"), alert: "この町ではその装備を購入できません。"
        return
      end
      unless params[:confirm_purchase] == "1"
        redirect_to game_path(panel: "weapon_shop", shop_menu: kind == "armor" ? "armors" : "weapons", equipment_name: definition.name), alert: "購入内容を確認してください。"
        return
      end
      if player.col.to_i < definition.price
        redirect_to game_path(panel: "weapon_shop"), alert: "コルが足りません。#{definition.name}は#{definition.price}コルです。"
        return
      end

      ActiveRecord::Base.transaction do
        player.update!(col: player.col.to_i - definition.price)
        if kind == "armor"
          player.armors.create!(definition.to_h.except(:location, :price, :description).merge(equipped: false))
        else
          player.weapons.create!(definition.to_h.except(:location, :price, :production_only).merge(equipped: false))
        end
      end
      redirect_to game_path(panel: "weapon_shop", shop_menu: kind == "armor" ? "armors" : "weapons"), notice: "#{definition.name}を購入した。"
    end

    def produce_weapon
      player = current_player

      unless BlacksmithFacilityAccessService.available?(player)
        redirect_to game_path, alert: BlacksmithFacilityAccessService.message_for(:craft)
        return
      end

      unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
        redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "blacksmith")
        redirect_to game_path, alert: FacilityHoursService.closed_message("blacksmith", player)
        return
      end

      context = BlacksmithService.context_for(player, mode: params[:smith_mode])
      result = WeaponCraftService.call(
        player: player,
        blacksmith: context,
        weapon_type: params[:weapon_type],
        ore_material: params[:ore_material],
        monster_material: params[:monster_material],
        support_material: params[:support_material]
      )
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "produce", smith_mode: params[:smith_mode]), flash_for(result)
    end

    def sell_weapon
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_weapon_shop?
        redirect_to game_path, alert: "武具店はまだ利用できません。"
        return
      end

      unless facility_open_for?(player, "weapon_shop")
        redirect_to game_path, alert: FacilityHoursService.closed_message("weapon_shop", player)
        return
      end

      weapon = player.weapons.find_by(id: params[:weapon_id])
      unless weapon
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons"), alert: "その武器は所持していません。"
        return
      end

      unless weapon.sellable_by_player?
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons"), alert: "装備中・お気に入り・保護対象の武器は売却できません。"
        return
      end
      unless params[:confirm_sell] == "1"
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons", weapon_id: weapon.id, confirm_sell: "1"), alert: "売却内容を確認してください。"
        return
      end
      if weapon.unique_item? && params[:confirm_unique] != "1"
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons", weapon_id: weapon.id, confirm_sell: "1"),
                    alert: "この武器は二度と手には入らないかもしれません。本当に売却しますか？"
        return
      end

      price = weapon.sell_price
      player.col = player.col.to_i + price
      player.advance_time!(10)

      ActiveRecord::Base.transaction do
        weapon.destroy!
        player.save!
      end

      redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "weapons"), notice: "#{weapon.name}を#{price}コルで売却した。"
    end

    def sell_armor
      player = current_player
      unless player.location&.safe_area? && player.town_discovery_for&.found_weapon_shop? && facility_open_for?(player, "weapon_shop")
        redirect_to game_path, alert: "武具店は利用できません。"
        return
      end
      armor = player.armors.find_by(id: params[:armor_id])
      unless armor&.sellable_by_player?
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "armors"), alert: "装備中・お気に入り・保護対象の防具は売却できません。"
        return
      end
      unless params[:confirm_sell] == "1"
        redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "armors", armor_id: armor.id, confirm_sell: "1"), alert: "売却内容を確認してください。"
        return
      end
      price = armor.sell_price
      ActiveRecord::Base.transaction do
        armor.destroy!
        player.col = player.col.to_i + price
        player.advance_time!(10)
        player.save!
      end
      redirect_to game_path(panel: "weapon_shop", shop_menu: "sell", sell_type: "armors"), notice: "#{armor.name}を#{price}コルで売却した。"
    end

    def equip_weapon
      player = current_player
      battle = current_battle
      weapon = player.weapons.find_by(id: params[:weapon_id])

      if battle
        blocked_result = BattleService.resolve_player_action_block!(player, battle)
        if blocked_result
          if blocked_result.status == :defeated
            redirect_to game_path(panel: "inn"), alert: blocked_result.message
          elsif blocked_result.status == :error
            redirect_to game_path(panel: "equipment"), alert: blocked_result.message
          else
            redirect_to game_path(battle_command: "attack"), notice: blocked_result.message
          end
          return
        end
      end

      unless weapon
        redirect_to game_path(panel: "equipment"), alert: "その武器は所持していません。"
        return
      end

      ActiveRecord::Base.transaction do
        if player.dual_wield?
          equipped_weapons = player.weapons.where(equipped: true).where.not(id: weapon.id).order(:updated_at)
          equipped_weapons.first.update!(equipped: false) if equipped_weapons.count >= 2
        else
          player.weapons.update_all(equipped: false)
        end

        weapon.update!(equipped: true)
        player.armors.where(slot: "shield").update_all(equipped: false) unless player.shield_equippable?
        StatusEffectService.clamp_hp_to_max!(player)
        player.save!
      end

      if battle
        enemy_result = BattleService.apply_enemy_attack!(player, battle)
        if enemy_result.status == :defeated
          redirect_to game_path(panel: "inn"), alert: "#{weapon.name}を装備した。#{enemy_result.message}"
        else
          redirect_to game_path(battle_command: "attack"), notice: "#{weapon.name}を装備した。#{enemy_result.message}"
        end
        return
      end

      redirect_to game_path(panel: "equipment"), notice: "#{weapon.name}を装備した。"
    end

    def unequip_weapon
      player = current_player
      weapon = player.weapons.find_by(id: params[:weapon_id])

      unless weapon&.equipped?
        redirect_to game_path(panel: "equipment"), alert: "その武器は装備していません。"
        return
      end

      ActiveRecord::Base.transaction do
        weapon.update!(equipped: false)
        StatusEffectService.clamp_hp_to_max!(player)
        player.save!
      end
      redirect_to game_path(panel: "equipment"), notice: "#{weapon.name}を外した。"
    end

    def equip_armor
      player = current_player
      battle = current_battle
      armor = player.armors.find_by(id: params[:armor_id])

      if battle
        blocked_result = BattleService.resolve_player_action_block!(player, battle)
        if blocked_result
          if blocked_result.status == :defeated
            redirect_to game_path(panel: "inn"), alert: blocked_result.message
          elsif blocked_result.status == :error
            redirect_to game_path(panel: "equipment"), alert: blocked_result.message
          else
            redirect_to game_path(battle_command: "attack"), notice: blocked_result.message
          end
          return
        end
      end

      unless armor
        redirect_to game_path(panel: "equipment"), alert: "その防具は所持していません。"
        return
      end
      if armor.slot == "shield" && !player.shield_equippable?
        redirect_to game_path(panel: "equipment"), alert: "盾は片手武器を装備している場合のみ装備できます。"
        return
      end

      ActiveRecord::Base.transaction do
        player.armors.where(slot: armor.slot).update_all(equipped: false)
        armor.update!(equipped: true)
        StatusEffectService.clamp_hp_to_max!(player)
        player.save!
      end
      if battle
        enemy_result = BattleService.apply_enemy_attack!(player, battle)
        if enemy_result.status == :defeated
          redirect_to game_path(panel: "inn"), alert: "#{armor.name}を装備した。#{enemy_result.message}"
        else
          redirect_to game_path(battle_command: "attack"), notice: "#{armor.name}を装備した。#{enemy_result.message}"
        end
        return
      end

      redirect_to game_path(panel: "equipment"), notice: "#{armor.name}を装備した。"
    end

    def unequip_armor
      player = current_player
      armor = player.armors.find_by(id: params[:armor_id])

      unless armor&.equipped?
        redirect_to game_path(panel: "equipment"), alert: "その防具は装備していません。"
        return
      end

      ActiveRecord::Base.transaction do
        armor.update!(equipped: false)
        StatusEffectService.clamp_hp_to_max!(player)
        player.save!
      end
      redirect_to game_path(panel: "equipment"), notice: "#{armor.name}を外した。"
    end

    private

    def shop_quantity_param
      [params[:quantity].to_i, 1].max
    end

    def facility_open_for?(player, facility_key)
      FacilityHoursService.open?(facility_key, player)
    end

    def repair_materials_for(weapons)
      weapons.each_with_object(Hash.new(0)) do |weapon, materials|
        weapon.repair_materials_required.each do |name, count|
          materials[name] += count.to_i
        end
      end
    end

    def missing_repair_materials_for(player, required_materials)
      required_materials.each_with_object({}) do |(name, required_count), missing|
        owned_count = player.items.where(name: name).sum(:quantity).to_i
        missing[name] = required_count - owned_count if owned_count < required_count
      end
    end

    def consume_repair_materials!(player, required_materials)
      required_materials.each do |name, required_count|
        remaining = required_count.to_i
        player.items.where(name: name).order(:id).each do |item|
          used = [item.quantity.to_i, remaining].min
          item.quantity = item.quantity.to_i - used
          remaining -= used
          item.quantity.to_i <= 0 ? item.destroy! : item.save!
          break if remaining <= 0
        end
      end
    end

    def format_materials(materials)
      materials.map { |name, count| "#{name} ×#{count}" }.join("、")
    end
  end
end
