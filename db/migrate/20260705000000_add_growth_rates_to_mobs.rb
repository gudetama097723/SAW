class AddGrowthRatesToMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :mobs, :hp_growth, :integer, null: false, default: 0
    add_column :mobs, :atk_growth, :integer, null: false, default: 0
    add_column :mobs, :agility_growth, :integer, null: false, default: 0
    add_column :mobs, :durability_growth, :integer, null: false, default: 0
    add_column :mobs, :col_growth, :integer, null: false, default: 0
  end
end
