class CreateBattleEnemies < ActiveRecord::Migration[8.1]
  def change
    create_table :battle_enemies do |t|
      t.references :battle, null: false, foreign_key: true
      t.references :mob, null: false, foreign_key: true
      t.integer :enemy_hp, null: false
      t.integer :position, null: false, default: 1
      t.text :part_states, null: false, default: "{}"

      t.timestamps
    end
  end
end
