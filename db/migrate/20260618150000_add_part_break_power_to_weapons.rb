class AddPartBreakPowerToWeapons < ActiveRecord::Migration[8.1]
  def change
    add_column :weapons, :part_break_power, :integer, null: false, default: 100
  end
end
