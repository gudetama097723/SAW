class CreateWeapons < ActiveRecord::Migration[8.1]
  def change
    create_table :weapons do |t|
      t.references :player, null: true, foreign_key: true
      t.references :mob, null: true, foreign_key: true
      t.string :name, null: false
      t.string :weapon_type, null: false
      t.string :rarity, default: "common", null: false
      t.integer :attack_power, default: 1, null: false
      t.integer :durability, default: 10, null: false
      t.integer :max_durability, default: 10, null: false
      t.integer :hp_bonus, default: 0, null: false
      t.integer :strength_bonus, default: 0, null: false
      t.integer :agility_bonus, default: 0, null: false
      t.integer :drop_rate, default: 0, null: false
      t.boolean :equipped, default: false, null: false

      t.timestamps
    end
  end
end
