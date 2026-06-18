class AdjustWeaponDurabilityValues < ActiveRecord::Migration[8.1]
  def up
    update_weapon_durability("スモールソード", 1000)
    update_weapon_durability("ブロンズソード", 1200)
    update_weapon_durability("錆びたショートソード", 600)
  end

  def down
    update_weapon_durability("スモールソード", 30)
    update_weapon_durability("ブロンズソード", 40)
    update_weapon_durability("錆びたショートソード", 18)
  end

  private

  def update_weapon_durability(name, value)
    execute "UPDATE weapons SET durability = #{value.to_i}, max_durability = #{value.to_i} WHERE name = #{connection.quote(name)}"
  end
end
