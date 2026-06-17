class AddLevelToMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :mobs, :level, :integer, default: 1, null: false
  end
end
