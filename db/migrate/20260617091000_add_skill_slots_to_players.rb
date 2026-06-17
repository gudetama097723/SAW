class AddSkillSlotsToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :skill_slots, :integer, default: 3, null: false
  end
end
