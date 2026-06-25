class FieldArea < ApplicationRecord
  belongs_to :route
  has_many :treasure_chests, dependent: :destroy
  has_many :boss_mobs, class_name: "Mob", dependent: :nullify
  has_many :npcs, dependent: :nullify
  has_many :player_field_area_progresses, dependent: :destroy

  scope :ordered, -> { order(:start_distance, :end_distance) }

  validates :name, presence: true
  validates :start_distance, :end_distance, presence: true

  def include_distance?(distance)
    start_distance.to_i <= distance.to_i && distance.to_i <= end_distance.to_i
  end
end
