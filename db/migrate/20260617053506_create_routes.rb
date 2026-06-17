class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.references :from_location, null: false, foreign_key: { to_table: :locations }
      t.references :to_location, null: false, foreign_key: { to_table: :locations }

      t.integer :travel_time
      t.integer :danger_level

      t.timestamps
    end
  end
end
