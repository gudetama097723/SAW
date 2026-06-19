class PlayerFieldAreaProgress < ApplicationRecord
  belongs_to :player
  belongs_to :field_area

  validates :mapping_progress,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
