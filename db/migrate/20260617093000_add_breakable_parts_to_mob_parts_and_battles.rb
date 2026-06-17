class AddBreakablePartsToMobPartsAndBattles < ActiveRecord::Migration[8.1]
  def change
    add_column :mob_parts, :max_durability, :integer, default: 10, null: false
    add_column :mob_parts, :break_effect, :string
    add_column :mob_parts, :drop_item_name, :string
    add_column :mob_parts, :drop_rate, :integer, default: 0, null: false
    add_column :battles, :part_states, :text, default: "{}", null: false
  end
end
