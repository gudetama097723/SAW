class CreateBattles < ActiveRecord::Migration[8.1]
  def change
    create_table :battles do |t|
      t.references :player, null: false, foreign_key: true
      t.references :mob, null: false, foreign_key: true
      t.integer :enemy_hp

      t.timestamps
    end
  end
end
