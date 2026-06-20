class PlayerBase < ApplicationRecord
  belongs_to :player
  belongs_to :location
  has_many :storage_items, dependent: :destroy
  has_many :stored_weapons, class_name: "Weapon", dependent: :nullify
  has_many :stored_armors, class_name: "Armor", dependent: :nullify

  def location_name
    label = temporary? ? "仮拠点" : "本拠点"
    "#{location.name}（#{label}）"
  end

  def home?
    base_type == "home"
  end

  def temporary?
    base_type == "temporary"
  end

  def storage_type_count
    storage_items.where("quantity > 0").count + stored_weapons.count + stored_armors.count
  end

  def remaining_storage_slots
    [storage_limit.to_i - storage_type_count, 0].max
  end

  def storage_full_for?(name, category)
    return false if storage_items.exists?(name: name, category: category)

    storage_type_count >= storage_limit.to_i
  end

  def storage_full_for_equipment?
    storage_type_count >= storage_limit.to_i
  end
end
