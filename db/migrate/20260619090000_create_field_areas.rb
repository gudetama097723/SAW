class CreateFieldAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :field_areas do |t|
      t.references :route, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :start_distance, null: false
      t.integer :end_distance, null: false
      t.integer :encounter_rate, null: false, default: 30
      t.integer :rest_safety, null: false, default: 70
      t.text :description

      t.timestamps
    end

    add_index :field_areas, [:route_id, :start_distance, :end_distance], name: "index_field_areas_on_route_and_distance"
  end
end
