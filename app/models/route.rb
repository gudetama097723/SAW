class Route < ApplicationRecord
  belongs_to :from_location, class_name: "Location"
  belongs_to :to_location, class_name: "Location"
  has_many :player_route_progresses, dependent: :destroy
  has_many :field_areas, dependent: :destroy
end
