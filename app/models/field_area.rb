class FieldArea < ApplicationRecord
  belongs_to :route

  scope :ordered, -> { order(:start_distance, :end_distance) }

  def include_distance?(distance)
    start_distance.to_i <= distance.to_i && distance.to_i <= end_distance.to_i
  end
end
