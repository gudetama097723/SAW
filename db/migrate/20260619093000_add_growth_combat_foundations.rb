class AddGrowthCombatFoundations < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :attack_attributes, :text, default: "斬撃", null: false
    add_column :weapons, :enhancement_level, :integer, default: 0, null: false
    add_column :weapons, :enhancement_data, :text, default: "{}", null: false

    add_column :mobs, :weak_attack_attribute, :string
    add_column :mob_parts, :weak_attack_attribute, :string

    add_column :skills, :skill_category, :string, default: "general", null: false
    add_column :skills, :weapon_skill, :boolean, default: false, null: false
    add_column :skills, :sword_skill_levels, :text, default: "{}", null: false
    add_column :skills, :learn_condition_data, :text, default: "{}", null: false

    add_column :treasure_chests, :hazard_type, :string, default: "normal", null: false
    add_column :treasure_chests, :hazard_level, :integer, default: 0, null: false
    add_column :player_treasure_chests, :inspected, :boolean, default: false, null: false
    add_column :player_treasure_chests, :inspection_result, :text
    add_column :player_treasure_chests, :ignored, :boolean, default: false, null: false

    add_column :players, :status_values, :text, default: "{}", null: false
    add_column :players, :injury_states, :text, default: "{}", null: false
    add_column :players, :skill_counters, :text, default: "{}", null: false

    add_column :armors, :status_resistance_data, :text, default: "{}", null: false
  end
end
