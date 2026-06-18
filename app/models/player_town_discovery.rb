class PlayerTownDiscovery < ApplicationRecord
  belongs_to :player
  belongs_to :location
end
