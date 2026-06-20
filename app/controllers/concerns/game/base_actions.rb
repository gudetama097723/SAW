module Game
  module BaseActions
    TRANSFER_BASE_COST = 20
    TRANSFER_INCLUDED_WEIGHT = 10.to_d
    TRANSFER_EXTRA_WEIGHT_COST = 3

    def set_home_base
      player = current_player
      location = player.location
      unless location&.safe_area? && player.town_discovery_for&.found_inn?
        redirect_to game_path(panel: "inn", inn_menu: "base"), alert: "宿屋を見つけていません。"
        return
      end

      temporary_only = location.name == "ホルンカの村"
      base_type = temporary_only ? "temporary" : "home"
      base_label = temporary_only ? "仮拠点" : "本拠点"

      unless params[:confirm] == "1"
        redirect_to game_path(panel: "inn", inn_menu: "base", confirm_home_base: "1"), notice: "ここを#{base_label}にしますか？"
        return
      end

      PlayerBase.transaction do
        player.player_bases.where(base_type: "home").update_all(active: false) if base_type == "home"
        player.player_bases.where(location: location, base_type: "home").update_all(active: false) if base_type == "temporary"
        player.player_bases.find_or_create_by!(location: location, base_type: base_type).update!(
          active: true,
          rent: base_type == "home" ? (location.name == "はじまりの街" ? 0 : 300) : 50,
          storage_limit: base_type == "home" ? 30 : 10
        )
      end
      redirect_to game_path(panel: "inn", inn_menu: "base"), notice: "#{location.name}を#{base_label}にした。"
    end

    def remove_temporary_base
      player = current_player
      base = player.player_bases.find_by(location: player.location, base_type: "temporary", active: true)

      unless base
        redirect_to game_path(panel: "inn", inn_menu: "base"), alert: "この宿屋は仮拠点ではありません。"
        return
      end

      returned_count = 0
      PlayerBase.transaction do
        base.storage_items.where("quantity > 0").find_each do |storage_item|
          item = player.items.find_or_initialize_by(name: storage_item.name, category: storage_item.category)
          item.quantity = item.quantity.to_i + storage_item.quantity.to_i
          returned_count += storage_item.quantity.to_i
          item.save!
        end
        base.stored_weapons.find_each { |weapon| weapon.update!(player: player, player_base: nil) }
        base.stored_armors.find_each { |armor| armor.update!(player: player, player_base: nil) }
        base.destroy!
      end

      redirect_to game_path(panel: "inn", inn_menu: "base"), notice: "仮拠点を解除した。収納中のアイテム#{returned_count}個と装備品を所持品へ戻した。"
    end

    def store_item
      player = current_player
      base = current_inn_base_for(player)
      item = player.items.find_by(id: params[:item_id])

      unless base
        redirect_to game_path(panel: "inn", inn_menu: "storage"), alert: "この宿屋は拠点ではありません。"
        return
      end

      unless item&.quantity.to_i.positive?
        redirect_to game_path(panel: "inn", inn_menu: "storage"), alert: "預けるアイテムがありません。"
        return
      end

      quantity = [params[:quantity].to_i, 1].max
      quantity = [quantity, item.quantity.to_i].min
      result = store_item_quantity!(player, base, item, quantity)
      redirect_to game_path(panel: "inn", inn_menu: "storage"), result
    end

    def store_weapon
      player = current_player
      base = current_inn_base_for(player)
      weapon = player.weapons.find_by(id: params[:weapon_id])
      result = store_weapon_to_base!(base, weapon)
      redirect_to game_path(panel: "inn", inn_menu: "storage", item_category: "weapons"), result
    end

    def store_armor
      player = current_player
      base = current_inn_base_for(player)
      armor = player.armors.find_by(id: params[:armor_id])
      result = store_armor_to_base!(base, armor)
      redirect_to game_path(panel: "inn", inn_menu: "storage", item_category: "armors"), result
    end

    def bulk_store_items
      player = current_player
      base = current_inn_base_for(player)
      category = params[:item_category].presence

      unless base
        redirect_to game_path(panel: "inn", inn_menu: "storage"), alert: "この宿屋は拠点ではありません。"
        return
      end

      stored_messages = []
      ActiveRecord::Base.transaction do
        if category.blank? || !%w[weapons armors].include?(category)
          items = player.items.where("quantity > 0")
          items = items.where(category: category) if category.present?
          items.find_each do |item|
            next if base.storage_full_for?(item.name, item.category)
            quantity = item.quantity.to_i
            storage_item = base.storage_items.find_or_initialize_by(name: item.name, category: item.category)
            storage_item.quantity = storage_item.quantity.to_i + quantity
            item.destroy!
            storage_item.save!
            stored_messages << "#{item.name}×#{quantity}"
          end
        end

        if category.blank? || category == "weapons"
          player.weapons.where(equipped: false, favorite: false).find_each do |weapon|
            next if base.storage_full_for_equipment?
            weapon.update!(player: nil, player_base: base, equipped: false)
            stored_messages << weapon.display_name
          end
        end

        if category.blank? || category == "armors"
          player.armors.where(equipped: false, favorite: false).find_each do |armor|
            next if base.storage_full_for_equipment?
            armor.update!(player: nil, player_base: base, equipped: false)
            stored_messages << armor.name
          end
        end
      end

      if stored_messages.any?
        redirect_to game_path(panel: "inn", inn_menu: "storage", item_category: category), notice: "#{stored_messages.size}種類を収納した。"
      else
        redirect_to game_path(panel: "inn", inn_menu: "storage", item_category: category), alert: "収納できる所持品がありません。"
      end
    end

    def deposit_base_col
      player = current_player
      base = player.player_bases.find_by(location: player.location, base_type: "home", active: true)
      amount = params[:amount].to_i

      unless base
        redirect_to game_path(panel: "inn"), alert: "この場所は本拠点ではありません。"
        return
      end
      if amount <= 0 || player.col.to_i < amount
        redirect_to game_path(panel: "inn"), alert: "預けるコルが足りません。"
        return
      end

      player.col = player.col.to_i - amount
      player.base_col = player.base_col.to_i + amount
      player.save!
      redirect_to game_path(panel: "inn"), notice: "#{amount}コルを預けた。"
    end

    def withdraw_base_col
      player = current_player
      base = player.player_bases.find_by(location: player.location, base_type: "home", active: true)
      amount = params[:amount].to_i

      unless base
        redirect_to game_path(panel: "inn"), alert: "この場所は本拠点ではありません。"
        return
      end
      if amount <= 0 || player.base_col.to_i < amount
        redirect_to game_path(panel: "inn"), alert: "引き出すコルが足りません。"
        return
      end

      player.base_col = player.base_col.to_i - amount
      player.col = player.col.to_i + amount
      player.save!
      redirect_to game_path(panel: "inn"), notice: "#{amount}コルを引き出した。"
    end

    def withdraw_item
      player = current_player
      base = current_inn_base_for(player)
      storage_item = base&.storage_items&.find_by(id: params[:storage_item_id])

      unless base
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw"), alert: "この宿屋は拠点ではありません。"
        return
      end

      unless storage_item&.quantity.to_i.positive?
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw"), alert: "取り出すアイテムがありません。"
        return
      end

      quantity = [params[:quantity].to_i, 1].max
      quantity = [quantity, storage_item.quantity.to_i].min
      item = player.items.find_or_initialize_by(name: storage_item.name, category: storage_item.category)

      ActiveRecord::Base.transaction do
        item.quantity = item.quantity.to_i + quantity
        storage_item.quantity -= quantity
        storage_item.quantity.to_i <= 0 ? storage_item.destroy! : storage_item.save!
        item.save!
      end

      redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: storage_item.category), notice: "#{item.name}を#{quantity}個取り出した。"
    end

    def withdraw_weapon
      player = current_player
      base = current_inn_base_for(player)
      weapon = base&.stored_weapons&.find_by(id: params[:weapon_id])
      unless weapon
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: "weapons"), alert: "取り出す武器がありません。"
        return
      end
      weapon.update!(player: player, player_base: nil)
      redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: params[:item_category].presence || "weapons"), notice: "#{weapon.display_name}を取り出した。"
    end

    def withdraw_armor
      player = current_player
      base = current_inn_base_for(player)
      armor = base&.stored_armors&.find_by(id: params[:armor_id])
      unless armor
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: "armors"), alert: "取り出す防具がありません。"
        return
      end
      armor.update!(player: player, player_base: nil)
      redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: params[:item_category].presence || "armors"), notice: "#{armor.name}を取り出した。"
    end

    def bulk_withdraw_items
      player = current_player
      base = current_inn_base_for(player)
      category = params[:item_category].presence
      moved_count = 0

      unless base
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw"), alert: "この宿屋は拠点ではありません。"
        return
      end

      ActiveRecord::Base.transaction do
        if category.blank? || !%w[weapons armors].include?(category)
          storage_items = base.storage_items.where("quantity > 0")
          storage_items = storage_items.where(category: category) if category.present?
          storage_items.find_each do |storage_item|
            item = player.items.find_or_initialize_by(name: storage_item.name, category: storage_item.category)
            item.quantity = item.quantity.to_i + storage_item.quantity.to_i
            moved_count += 1
            item.save!
            storage_item.destroy!
          end
        end

        if category.blank? || category == "weapons"
          base.stored_weapons.find_each { |weapon| weapon.update!(player: player, player_base: nil); moved_count += 1 }
        end

        if category.blank? || category == "armors"
          base.stored_armors.find_each { |armor| armor.update!(player: player, player_base: nil); moved_count += 1 }
        end
      end

      if moved_count.positive?
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: category), notice: "#{moved_count}種類を取り出した。"
      else
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "withdraw", item_category: category), alert: "取り出せるものがありません。"
      end
    end

    def transfer_base_item
      player = current_player
      source_base = current_inn_base_for(player)
      destination_base = player.player_bases.find_by(id: params[:destination_base_id], active: true)

      unless source_base && destination_base && destination_base.player_id == player.id && destination_base.id != source_base.id
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "transfer"), alert: "輸送先の拠点がありません。"
        return
      end

      storage_items = selected_storage_items(source_base)
      weapons = source_base.stored_weapons.where(id: Array(params[:weapon_ids]).reject(&:blank?))
      armors = source_base.stored_armors.where(id: Array(params[:armor_ids]).reject(&:blank?))
      if storage_items.empty? && weapons.empty? && armors.empty?
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "transfer"), alert: "輸送するアイテムを選択してください。"
        return
      end

      total_weight = storage_items.sum { |storage_item| storage_item_weight(storage_item, storage_item.quantity.to_i) } + weapons.sum { |weapon| weapon.weight.to_d } + armors.sum { |armor| armor.weight.to_d }
      cost = transfer_item_cost(source_base, destination_base, total_weight)

      if params[:confirm] != "1"
        transfer_labels = storage_items.map { |item| "#{item.name}×#{item.quantity}" } + weapons.map(&:display_name) + armors.map(&:name)
        redirect_to game_path(
          panel: "inn",
          inn_menu: "storage",
          storage_tab: "transfer",
          confirm_transfer: "1",
          destination_base_id: destination_base.id,
          storage_item_ids: storage_items.pluck(:id),
          weapon_ids: weapons.pluck(:id),
          armor_ids: armors.pluck(:id),
          transfer_cost: cost,
          transfer_weight: total_weight.to_f.round(2),
          transfer_labels: transfer_labels.join("、")
        )
        return
      end

      if player.col.to_i < cost
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "transfer"), alert: "輸送費#{cost}コルが足りません。"
        return
      end

      new_kind_count = storage_items.count { |storage_item| !destination_base.storage_items.exists?(name: storage_item.name, category: storage_item.category) } + weapons.count + armors.count
      if destination_base.remaining_storage_slots < new_kind_count
        redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "transfer"), alert: "輸送先の収納の空き種類数が足りません。"
        return
      end

      ActiveRecord::Base.transaction do
        player.col = player.col.to_i - cost
        storage_items.each do |storage_item|
          destination_item = destination_base.storage_items.find_or_initialize_by(name: storage_item.name, category: storage_item.category)
          destination_item.quantity = destination_item.quantity.to_i + storage_item.quantity.to_i
          destination_item.save!
          storage_item.destroy!
        end
        weapons.update_all(player_base_id: destination_base.id, updated_at: Time.current)
        armors.update_all(player_base_id: destination_base.id, updated_at: Time.current)
        player.save!
      end

      redirect_to game_path(panel: "inn", inn_menu: "storage", storage_tab: "transfer"), notice: "#{destination_base.location.name}へ輸送した。重量#{total_weight.to_f.round(2)}、輸送費#{cost}コル。"
    end

    private

    def current_inn_base_for(player)
      base_type = player.location&.name == "ホルンカの村" ? "temporary" : "home"
      player.player_bases.find_by(location: player.location, base_type: base_type, active: true)
    end

    def store_item_quantity!(player, base, item, quantity)
      return { alert: "収納の空き種類数が足りません。" } if base.storage_full_for?(item.name, item.category)

      storage_item = base.storage_items.find_or_initialize_by(name: item.name, category: item.category)
      ActiveRecord::Base.transaction do
        storage_item.quantity = storage_item.quantity.to_i + quantity
        item.quantity -= quantity
        item.quantity.to_i <= 0 ? item.destroy! : item.save!
        storage_item.save!
      end
      { notice: "#{storage_item.name}を#{quantity}個収納した。" }
    end

    def store_weapon_to_base!(base, weapon)
      return { alert: "この宿屋は拠点ではありません。" } unless base
      return { alert: "預ける武器がありません。" } unless weapon
      return { alert: "装備中・お気に入り・保護対象の武器は預けられません。" } if weapon.equipped? || weapon.favorite? || weapon.protected_from_death_penalty?
      return { alert: "収納の空き種類数が足りません。" } if base.storage_full_for_equipment?

      weapon.update!(player: nil, player_base: base, equipped: false)
      { notice: "#{weapon.display_name}を収納した。" }
    end

    def store_armor_to_base!(base, armor)
      return { alert: "この宿屋は拠点ではありません。" } unless base
      return { alert: "預ける防具がありません。" } unless armor
      return { alert: "装備中・お気に入り・保護対象の防具は預けられません。" } if armor.equipped? || armor.favorite? || armor.protected_from_death_penalty?
      return { alert: "収納の空き種類数が足りません。" } if base.storage_full_for_equipment?

      armor.update!(player: nil, player_base: base, equipped: false)
      { notice: "#{armor.name}を収納した。" }
    end

    def selected_storage_items(base)
      ids = Array(params[:storage_item_ids]).reject(&:blank?)
      ids = [params[:storage_item_id]] if ids.empty? && params[:storage_item_id].present?
      base.storage_items.where(id: ids)
    end

    def storage_item_weight(storage_item, quantity)
      Item.new(name: storage_item.name, category: storage_item.category, quantity: quantity).total_weight
    end

    def transfer_minimum_cost(source_base, destination_base)
      danger = [source_base.location&.danger_level.to_i, destination_base.location&.danger_level.to_i].max
      TRANSFER_BASE_COST + danger * 5
    end

    def transfer_item_cost(source_base, destination_base, total_weight)
      minimum = transfer_minimum_cost(source_base, destination_base)
      extra_weight = [total_weight.to_d - TRANSFER_INCLUDED_WEIGHT, 0.to_d].max
      minimum + (extra_weight * TRANSFER_EXTRA_WEIGHT_COST).ceil
    end
  end
end


