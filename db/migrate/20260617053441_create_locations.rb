class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name
      t.integer :floor
      t.integer :danger_level
      t.boolean :safe_area

      t.timestamps
    end
  end
end
