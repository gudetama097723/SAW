class CreateMobParts < ActiveRecord::Migration[8.1]
  def change
    create_table :mob_parts do |t|
      t.references :mob, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :damage_multiplier, default: 80, null: false
      t.boolean :weakness, default: false, null: false

      t.timestamps
    end
  end
end
