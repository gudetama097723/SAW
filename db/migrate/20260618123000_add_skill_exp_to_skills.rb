class AddSkillExpToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :skills, :skill_exp, :integer, null: false, default: 0
  end
end
