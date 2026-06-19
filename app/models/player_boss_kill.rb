class PlayerBossKill < ApplicationRecord
  belongs_to :player
  belongs_to :mob
end
