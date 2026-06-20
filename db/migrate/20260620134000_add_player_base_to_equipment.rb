class AddPlayerBaseToEquipment < ActiveRecord::Migration[8.0]
  def change
    add_reference :weapons, :player_base, foreign_key: true
    add_reference :armors, :player_base, foreign_key: true
    change_column_null :armors, :player_id, true
  end
end
