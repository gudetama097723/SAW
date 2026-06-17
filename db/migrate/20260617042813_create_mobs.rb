class CreateMobs < ActiveRecord::Migration[8.1]
  def change
    create_table :mobs do |t|
      t.string :name
      t.integer :hp
      t.integer :atk
      t.string :rarity

      t.timestamps
    end
  end
end
