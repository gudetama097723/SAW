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
end
