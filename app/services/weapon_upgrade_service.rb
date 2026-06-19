class WeaponUpgradeService
  Result = Struct.new(:status, :message, keyword_init: true)

  def self.upgrade!(player, weapon)
    return Result.new(status: :error, message: "その武器は所持していません。") unless weapon&.player_id == player.id
    return Result.new(status: :error, message: "これ以上強化できません。") if weapon.max_enhancement?

    recipe = recipe_for(weapon)
    required_col = recipe&.required_col.to_i
    materials = recipe&.required_materials || default_materials_for(weapon)
    return Result.new(status: :error, message: "コルが足りません。強化には#{required_col}コル必要です。") if player.col.to_i < required_col

    missing = materials.find do |name, quantity|
      player.items.find_by(name: name)&.quantity.to_i < quantity.to_i
    end
    return Result.new(status: :error, message: "素材が足りません。#{missing.first} ×#{missing.last}が必要です。") if missing

    ActiveRecord::Base.transaction do
      materials.each do |name, quantity|
        item = player.items.find_by!(name: name)
        item.quantity -= quantity.to_i
        item.quantity.to_i <= 0 ? item.destroy! : item.save!
      end
      player.col = player.col.to_i - required_col
      player.advance_time!(30)
      weapon.enhancement_level = weapon.enhancement_level.to_i + 1
      player.save!
      weapon.save!
    end

    Result.new(status: :ok, message: "#{weapon.display_name}に強化した。")
  end

  def self.recipe_for(weapon)
    WeaponUpgradeRecipe.find_by(weapon_name: weapon.name, target_level: weapon.enhancement_level.to_i + 1) ||
      WeaponUpgradeRecipe.find_by(weapon_type: weapon.weapon_type, target_level: weapon.enhancement_level.to_i + 1)
  end

  def self.default_materials_for(_weapon)
    { "硬い甲殻" => 1 }
  end
end
