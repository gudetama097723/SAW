class ReworkWeaponEvolutionRuleConditions < ActiveRecord::Migration[8.1]
  def change
    remove_column :weapon_evolution_rules, :required_enhancement_level, :integer, default: 10, null: false
    add_column :weapon_evolution_rules, :required_conditions_data, :text, default: "[]", null: false
    add_column :weapon_evolution_rules, :required_smith_proficiency, :integer, default: 0, null: false
  end
end
