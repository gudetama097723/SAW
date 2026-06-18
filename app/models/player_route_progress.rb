class PlayerRouteProgress < ApplicationRecord
  belongs_to :player
  belongs_to :route

  validates :progress, numericality: { greater_than_or_equal_to: 0 }
end
