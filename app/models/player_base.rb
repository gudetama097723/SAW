class PlayerBase < ApplicationRecord
  belongs_to :player
  belongs_to :location
  has_many :storage_items, dependent: :destroy

  def home?
    base_type == "home"
  end

  def temporary?
    base_type == "temporary"
  end

  def storage_type_count
    storage_items.where("quantity > 0").count
  end

  def storage_full_for?(name, category)
    return false if storage_items.exists?(name: name, category: category)

    storage_type_count >= storage_limit.to_i
  end
end
