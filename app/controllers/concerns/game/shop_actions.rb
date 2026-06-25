module Game
  module ShopActions
    def item_shop
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
        return
      end

      result = ItemService.buy_shop_item!(player, params[:item_name].presence || "ポーション")
      redirect_to game_path(panel: "item_shop", shop_menu: "buy"), flash_for(result)
    end

    def produce_item
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
        return
      end

      result = ItemService.produce_potion!(player)
      redirect_to game_path(panel: "item_shop", shop_menu: "produce"), flash_for(result)
    end

    def sell_item
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_item_shop?
        redirect_to game_path, alert: "道具屋はまだ利用できません。"
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
    weapon = current_player.weapons.find_by(id: params[:weapon_id])
    result = WeaponUpgradeService.upgrade!(current_player, weapon)
    redirect_to game_path(panel: "blacksmith", blacksmith_menu: "upgrade", weapon_id: weapon&.id), flash_for(result)
  end

  def evolve_weapon
    weapon = current_player.weapons.find_by(id: params[:weapon_id])
    rule = WeaponEvolutionRule.find_by(source_weapon_name: weapon&.name)
    if !weapon || !rule
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve"), alert: "進化できる武器ではありません。"
      return
    end
    unless weapon.max_enhancement?
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", weapon_id: weapon.id), alert: "+10まで強化した武器のみ進化できます。"
      return
    end
    if current_player.level.to_i < rule.required_player_level.to_i
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve", weapon_id: weapon.id), alert: "鍛冶屋「お前にはまだ早い」"
      return
    end

    weapon.update!(name: rule.target_weapon_name, enhancement_level: 0)
    redirect_to game_path(panel: "blacksmith", blacksmith_menu: "evolve"), notice: "#{rule.target_weapon_name}へ進化した。"
  end

    def blacksmith
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
        redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
        return
      end

      weapon = player.equipped_weapon
      unless weapon
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), alert: "手入れする武器がありません。"
        return
      end

      price = weapon.repair_cost
      if price <= 0
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), notice: "#{weapon.name}は十分に手入れされています。"
        return
      end

      if player.col.to_i < price
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), alert: "コルが足りません。#{weapon.name}の手入れには#{price}コル必要です。"
        return
      end

      player.col = player.col.to_i - price
      player.advance_time!(20)
      weapon.durability = weapon.max_durability

      ActiveRecord::Base.transaction do
        player.save!
        weapon.save!
      end

      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "repair"), notice: "鍛冶屋で#{weapon.name}を手入れした。耐久力が全回復した。#{price}コル支払った。"
    end

    def buy_bronze_sword
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
        redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
        return
      end

      weapon_definition = ShopCatalog.blacksmith_weapon(player.location, params[:weapon_name].presence || "ブロンズソード")
      unless weapon_definition
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "buy"), alert: "この町ではその武器を購入できません。"
        return
      end

      price = weapon_definition.price
      if player.col.to_i < price
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "buy"), alert: "コルが足りません。#{weapon_definition.name}は#{price}コルです。"
        return
      end

      player.col = player.col.to_i - price
      player.weapons.create!(
        name: weapon_definition.name,
        weapon_type: weapon_definition.weapon_type,
        rarity: weapon_definition.rarity,
        attack_power: weapon_definition.attack_power,
        durability: weapon_definition.durability,
        max_durability: weapon_definition.max_durability,
        hp_bonus: weapon_definition.hp_bonus,
        strength_bonus: weapon_definition.strength_bonus,
        agility_bonus: weapon_definition.agility_bonus,
        critical_rate: weapon_definition.critical_rate,
        part_break_power: weapon_definition.part_break_power,
        attack_attributes: weapon_definition.attack_attributes,
        weight: weapon_definition.weight,
        strength_ratio: weapon_definition.strength_ratio,
        agility_ratio: weapon_definition.agility_ratio,
        description: weapon_definition.description,
        equipped: false
      )
      player.save!

      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "buy"), notice: "#{weapon_definition.name}を購入した。"
    end

    def produce_weapon
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
        redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
        return
      end

      result = WeaponProductionService.produce!(player, params[:weapon_name].to_s)
      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "produce", weapon_name: params[:weapon_name].presence), flash_for(result)
    end

    def sell_weapon
      player = current_player

      unless player.location&.safe_area? && player.town_discovery_for&.found_blacksmith?
        redirect_to game_path, alert: "鍛冶屋はまだ利用できません。"
        return
      end

      weapon = player.weapons.find_by(id: params[:weapon_id])
      unless weapon
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "その武器は所持していません。"
        return
      end

      unless weapon.sellable_by_player?
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), alert: "装備中・お気に入り・保護対象の武器は売却できません。"
        return
      end
      if weapon.unique_item? && params[:confirm_unique] != "1"
        redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell", confirm_weapon_id: weapon.id),
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

      redirect_to game_path(panel: "blacksmith", blacksmith_menu: "sell"), notice: "#{weapon.name}を#{price}コルで売却した。"
    end

    def equip_weapon
      player = current_player
      battle = current_battle
      weapon = player.weapons.find_by(id: params[:weapon_id])

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

      weapon.update!(equipped: false)
      redirect_to game_path(panel: "equipment"), notice: "#{weapon.name}を外した。"
    end

    def equip_armor
      player = current_player
      armor = player.armors.find_by(id: params[:armor_id])

      unless armor
        redirect_to game_path(panel: "equipment"), alert: "その防具は所持していません。"
        return
      end

      ActiveRecord::Base.transaction do
        player.armors.where(slot: armor.slot).update_all(equipped: false)
        armor.update!(equipped: true)
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

      armor.update!(equipped: false)
      redirect_to game_path(panel: "equipment"), notice: "#{armor.name}を外した。"
    end
  end
end
