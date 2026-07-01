class CreateKeyItems < ActiveRecord::Migration[8.1]
  def change
    create_table :key_items do |t|
      t.references :player, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :category, null: false, default: "story"
      t.string :unique_key
      t.datetime :obtained_at

      t.timestamps
    end

    add_index :key_items, [:player_id, :unique_key], unique: true, where: "unique_key IS NOT NULL"
  end
end
