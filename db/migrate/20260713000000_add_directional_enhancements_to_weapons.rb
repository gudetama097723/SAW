class AddDirectionalEnhancementsToWeapons < ActiveRecord::Migration[8.1]
  def up
    add_column :weapons, :enhance_limit, :integer, default: 3, null: false
    add_column :weapons, :enhance_attempts, :integer, default: 0, null: false
    add_column :weapons, :enhance_difficulty, :integer, default: 20, null: false
    add_column :weapons, :sharpness_level, :integer, default: 0, null: false
    add_column :weapons, :quickness_level, :integer, default: 0, null: false
    add_column :weapons, :accuracy_level, :integer, default: 0, null: false
    add_column :weapons, :heaviness_level, :integer, default: 0, null: false
    add_column :weapons, :durability_level, :integer, default: 0, null: false
    add_column :weapons, :durability_loss_remainder, :decimal, precision: 8, scale: 4, default: 0, null: false

    execute <<~SQL.squish
      UPDATE weapons
      SET sharpness_level = enhancement_level,
          enhance_attempts = enhancement_level,
          enhance_limit = CASE WHEN enhancement_level > enhance_limit THEN enhancement_level ELSE enhance_limit END
      WHERE enhancement_level > 0
    SQL
  end

  def down
    remove_column :weapons, :durability_loss_remainder
    remove_column :weapons, :durability_level
    remove_column :weapons, :heaviness_level
    remove_column :weapons, :accuracy_level
    remove_column :weapons, :quickness_level
    remove_column :weapons, :sharpness_level
    remove_column :weapons, :enhance_difficulty
    remove_column :weapons, :enhance_attempts
    remove_column :weapons, :enhance_limit
  end
end
