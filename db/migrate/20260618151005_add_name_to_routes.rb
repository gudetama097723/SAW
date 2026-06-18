class AddNameToRoutes < ActiveRecord::Migration[8.1]
  def change
    add_column :routes, :name, :string, null: false, default: "名もなき道"
  end
end
