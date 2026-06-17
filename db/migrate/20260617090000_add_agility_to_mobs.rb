class AddAgilityToMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :mobs, :agility, :integer, default: 1, null: false
  end
end
