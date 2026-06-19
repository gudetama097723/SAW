class CreatePlayerFieldAreaProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :player_field_area_progresses do |t|
      t.references :player, null: false, foreign_key: true
      t.references :field_area, null: false, foreign_key: true
      t.integer :mapping_progress, null: false, default: 0

      t.timestamps
    end

    add_index :player_field_area_progresses,
              [:player_id, :field_area_id],
              unique: true,
              name: "index_player_area_progress_unique"
  end
end
