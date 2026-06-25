class AddBuffEffects < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :buff_effects, :text, default: "{}", null: false
    add_column :players, :battle_effects, :text, default: "{}", null: false
    add_column :battle_enemies, :battle_effects, :text, default: "{}", null: false
  end
end
