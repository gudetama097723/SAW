class RebalanceExistingWeaponDifficulties < ActiveRecord::Migration[8.1]
  SETTINGS = {
    "スモールソード" => [ 10, 0.7 ],
    "ブロンズソード" => [ 10, 0.7 ],
    "ブロンズレイピア" => [ 10, 0.8 ],
    "ウッドメイス" => [ 10, 0.6 ],
    "蒼狼の牙剣" => [ 8, 2.0 ],
    "アイアンショートソード" => [ 8, 1.0 ],
    "ハンドアックス" => [ 6, 1.1 ],
    "スティンガーレイピア" => [ 8, 1.2 ],
    "錆びたショートソード" => [ 10, 0.6 ],
    "斥候のショートソード" => [ 10, 0.8 ]
  }.freeze

  def up
    SETTINGS.each do |name, (limit, difficulty)|
      execute <<~SQL.squish
        UPDATE weapons
        SET enhance_limit = CASE WHEN enhance_attempts > #{limit} THEN enhance_attempts ELSE #{limit} END,
            enhancement_difficulty = #{difficulty}
        WHERE name = #{connection.quote(name)}
      SQL
    end
  end

  def down
    SETTINGS.each_key do |name|
      execute "UPDATE weapons SET enhancement_difficulty = 1.0 WHERE name = #{connection.quote(name)}"
    end
  end
end
