class AddMappingDifficultyToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :mapping_difficulty, :decimal, precision: 4, scale: 2, null: false, default: 1.0
  end
end
