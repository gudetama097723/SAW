class Location < ApplicationRecord
  has_many :outgoing_routes, class_name: "Route", foreign_key: "from_location_id"
  has_many :incoming_routes, class_name: "Route", foreign_key: "to_location_id"
  has_many :field_areas, through: :outgoing_routes, source: :field_areas
end
