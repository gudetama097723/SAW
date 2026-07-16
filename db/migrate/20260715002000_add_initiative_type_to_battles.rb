class AddInitiativeTypeToBattles < ActiveRecord::Migration[8.1]
  def change
    add_column :battles, :initiative_type, :string, default: "normal", null: false
  end
end
