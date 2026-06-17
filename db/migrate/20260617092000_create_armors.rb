class CreateArmors < ActiveRecord::Migration[8.1]
  def change
    create_table :armors do |t|
      t.references :player, null: false, foreign_key: true
      t.string :name, null: false
      t.string :armor_type, null: false
      t.string :slot, null: false
      t.string :rarity, null: false, default: "common"
      t.integer :defense, null: false, default: 0
      t.integer :weight, null: false, default: 0
      t.integer :hp_bonus, null: false, default: 0
      t.integer :strength_bonus, null: false, default: 0
      t.integer :agility_bonus, null: false, default: 0
      t.boolean :equipped, null: false, default: false

      t.timestamps
    end
  end
end
