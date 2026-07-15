class NormalizeEquippedItems < ActiveRecord::Migration[8.1]
  STARTER_WEAPON_NAMES = %w[スモールソード].freeze
  STARTER_ARMOR_NAMES = %w[レザーチュニック レザートラウザー レザーブーツ].freeze

  class MigrationWeapon < ActiveRecord::Base
    self.table_name = "weapons"
  end

  class MigrationArmor < ActiveRecord::Base
    self.table_name = "armors"
  end

  class MigrationSkill < ActiveRecord::Base
    self.table_name = "skills"
  end

  def up
    normalize_weapons
    normalize_armors

    add_index :armors, %i[player_id slot], unique: true,
      where: "equipped = 1 AND player_id IS NOT NULL",
      name: "index_armors_on_unique_equipped_slot"
  end

  def down
    remove_index :armors, name: "index_armors_on_unique_equipped_slot"
  end

  private

  def normalize_weapons
    player_ids = MigrationWeapon.where(equipped: true).where.not(player_id: nil)
      .group(:player_id).having("COUNT(*) > 1").pluck(:player_id)

    player_ids.each do |player_id|
      equipped = MigrationWeapon.where(player_id: player_id, equipped: true).to_a
      limit = MigrationSkill.exists?(player_id: player_id, name: "二刀流") ? 2 : 1
      next if equipped.size <= limit

      keep_ids = preferred_items(equipped, STARTER_WEAPON_NAMES).last(limit).map(&:id)
      MigrationWeapon.where(id: equipped.map(&:id) - keep_ids).update_all(equipped: false)
    end
  end

  def normalize_armors
    duplicates = MigrationArmor.where(equipped: true).where.not(player_id: nil)
      .group(:player_id, :slot).having("COUNT(*) > 1").pluck(:player_id, :slot)

    duplicates.each do |player_id, slot|
      equipped = MigrationArmor.where(player_id: player_id, slot: slot, equipped: true).to_a
      keep_id = preferred_items(equipped, STARTER_ARMOR_NAMES).last.id
      MigrationArmor.where(id: equipped.map(&:id) - [ keep_id ]).update_all(equipped: false)
    end
  end

  def preferred_items(items, starter_names)
    items.sort_by do |item|
      [ starter_names.include?(item.name) ? 0 : 1, item.updated_at || Time.at(0), item.id ]
    end
  end
end
