class CreateSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :skills do |t|
      t.references :player, null: false, foreign_key: true
      t.string :name
      t.integer :proficiency

      t.timestamps
    end
  end
end
