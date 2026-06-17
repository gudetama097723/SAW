class AddMappingProgressToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :mapping_progress, :integer, default: 0, null: false
  end
end
