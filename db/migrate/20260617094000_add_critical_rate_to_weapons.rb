class AddCriticalRateToWeapons < ActiveRecord::Migration[8.1]
  def change
    add_column :weapons, :critical_rate, :integer, default: 5, null: false
  end
end
