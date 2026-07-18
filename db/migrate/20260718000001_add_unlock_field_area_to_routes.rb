class AddUnlockFieldAreaToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :unlock_field_area_id, :integer
    add_column :routes, :unlock_required_mapping, :integer, default: 0, null: false
    add_index :routes, :unlock_field_area_id
  end
end
