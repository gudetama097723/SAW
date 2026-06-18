class AddDistanceToRoutes < ActiveRecord::Migration[8.0]
  def change
    add_column :routes, :distance, :integer, null: false, default: 100
  end
end
