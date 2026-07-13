class BackfillWeaponEnhancementSettings < ActiveRecord::Migration[8.1]
  SETTINGS = {
    "スモールソード" => [ 10, 10 ],
    "ブロンズソード" => [ 10, 10 ],
    "ブロンズレイピア" => [ 10, 12 ],
    "ウッドメイス" => [ 10, 10 ],
    "蒼狼の牙剣" => [ 8, 25 ],
    "アイアンショートソード" => [ 8, 20 ],
    "ハンドアックス" => [ 6, 18 ],
    "スティンガーレイピア" => [ 8, 22 ]
  }.freeze

  def up
    SETTINGS.each do |name, (limit, difficulty)|
      quoted_name = connection.quote(name)
      execute <<~SQL.squish
        UPDATE weapons
        SET enhance_limit = CASE WHEN enhance_attempts > #{limit} THEN enhance_attempts ELSE #{limit} END,
            enhance_difficulty = #{difficulty}
        WHERE name = #{quoted_name}
      SQL
    end
  end

  def down
    SETTINGS.each_key do |name|
      execute "UPDATE weapons SET enhance_limit = 3, enhance_difficulty = 20 WHERE name = #{connection.quote(name)}"
    end
  end
end
