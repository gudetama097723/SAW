class CreateFieldAreas < ActiveRecord::Migration[8.0]
  def change
    create_table :field_areas do |t|
      t.references :route, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :start_position, null: false
      t.integer :end_position, null: false
      t.integer :danger_level, null: false, default: 1
      t.integer :required_mapping_to_enter_next, null: false, default: 30
      t.integer :required_mapping_to_reach_town, null: false, default: 40

      t.timestamps
    end

    add_index :field_areas, [:route_id, :start_distance, :end_distance], name: "index_field_areas_on_route_and_distance"
  end
end
