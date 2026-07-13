class RefineWeaponDifficultyAndBlacksmiths < ActiveRecord::Migration[8.1]
  def up
    add_column :weapons, :enhancement_difficulty, :decimal, precision: 6, scale: 2, default: 1.0, null: false
    execute "UPDATE weapons SET enhancement_difficulty = enhance_difficulty / 10.0"
    remove_column :weapons, :enhance_difficulty

    add_column :npcs, :blacksmith_base_proficiency, :integer, default: 0, null: false
    add_column :npcs, :blacksmith_max_proficiency, :integer, default: 0, null: false
    add_column :npc_discoveries, :blacksmith_proficiency_bonus, :integer, default: 0, null: false
  end

  def down
    add_column :weapons, :enhance_difficulty, :integer, default: 10, null: false
    execute "UPDATE weapons SET enhance_difficulty = ROUND(enhancement_difficulty * 10)"
    remove_column :weapons, :enhancement_difficulty

    remove_column :npc_discoveries, :blacksmith_proficiency_bonus
    remove_column :npcs, :blacksmith_max_proficiency
    remove_column :npcs, :blacksmith_base_proficiency
  end
end
