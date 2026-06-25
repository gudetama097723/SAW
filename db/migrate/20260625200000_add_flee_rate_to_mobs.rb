class AddFleeRateToMobs < ActiveRecord::Migration[8.0]
  def change
    add_column :mobs, :flee_rate, :integer, null: false, default: 0
  end
end
