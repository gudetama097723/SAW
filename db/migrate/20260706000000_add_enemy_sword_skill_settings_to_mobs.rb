class AddEnemySwordSkillSettingsToMobs < ActiveRecord::Migration[8.1]
  def change
    add_column :mobs, :enemy_sword_skill_proficiency, :integer
    add_column :mobs, :enemy_sword_skill_keys, :text, null: false, default: ""
  end
end
