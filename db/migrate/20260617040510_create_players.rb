class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name
      t.integer :hp
      t.integer :col
      t.integer :floor

      t.timestamps
    end
  end
end
