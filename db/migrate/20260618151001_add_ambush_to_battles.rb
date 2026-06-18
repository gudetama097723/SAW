class AddAmbushToBattles < ActiveRecord::Migration[8.1]
  def change
    add_column :battles, :ambush, :boolean, default: false, null: false
  end
end
