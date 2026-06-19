class AddMappingRequirementsToFieldAreas < ActiveRecord::Migration[8.1]
  def change
    add_column :field_areas, :required_mapping_to_enter_next, :integer, default: 30, null: false
    add_column :field_areas, :required_mapping_to_reach_town, :integer, default: 0, null: false
  end
end
