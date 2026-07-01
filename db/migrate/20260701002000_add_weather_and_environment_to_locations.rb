class AddWeatherAndEnvironmentToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :weather, :string, null: false, default: "clear"
    add_column :locations, :environment, :string, null: false, default: "normal"
  end
end
