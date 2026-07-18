class Route < ApplicationRecord
  belongs_to :from_location, class_name: "Location"
  belongs_to :to_location, class_name: "Location"
  belongs_to :unlock_field_area, class_name: "FieldArea", optional: true
  has_many :player_route_progresses, dependent: :destroy
  has_many :field_areas, dependent: :destroy
  has_many :treasure_chests, dependent: :destroy
  has_many :boss_mobs, class_name: "Mob", dependent: :nullify

  def locked?
    unlock_field_area_id.present?
  end

  # 分岐ルートはfrom_locationを実際には持たない(技術上の便宜値)ため、
  # 「戻る」先の名称は分岐元ルートの名前を返す。
  def backward_destination_name
    locked? ? unlock_field_area.route.name : from_location.name
  end
end
