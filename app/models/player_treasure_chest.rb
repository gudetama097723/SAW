class PlayerTreasureChest < ApplicationRecord
  belongs_to :player
  belongs_to :treasure_chest
end
