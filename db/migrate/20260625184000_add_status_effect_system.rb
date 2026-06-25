class AddStatusEffectSystem < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :status_effects, :text, default: "{}", null: false
    add_column :battle_enemies, :status_values, :text, default: "{}", null: false
    add_column :battle_enemies, :status_effects, :text, default: "{}", null: false
    add_column :mobs, :status_threshold_data, :text, default: "{}", null: false
    add_column :mobs, :status_attack_data, :text, default: "{}", null: false
    add_column :weapons, :status_resistance_data, :text, default: "{}", null: false
  end
end
