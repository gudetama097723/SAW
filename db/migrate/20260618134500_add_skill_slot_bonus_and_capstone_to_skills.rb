class AddSkillSlotBonusAndCapstoneToSkills < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :skill_slot_bonus, :integer, null: false, default: 0
    add_column :skills, :capstone_slot_awarded, :boolean, null: false, default: false
  end
end
