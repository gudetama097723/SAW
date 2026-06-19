class Route < ApplicationRecord
  belongs_to :from_location, class_name: "Location"
  belongs_to :to_location, class_name: "Location"
  has_many :player_route_progresses, dependent: :destroy
  has_many :field_areas, dependent: :destroy
  has_many :treasure_chests, dependent: :destroy
  has_many :boss_mobs, class_name: "Mob", dependent: :nullify
end
