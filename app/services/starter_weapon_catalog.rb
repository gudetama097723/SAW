class StarterWeaponCatalog
  Choice = Struct.new(
    :key,
    :name,
    :weapon_type,
    :rarity,
    :attack_power,
    :durability,
    :max_durability,
    :hp_bonus,
    :strength_bonus,
    :agility_bonus,
    :critical_rate,
    :part_break_power,
    :attack_attributes,
    :weight,
    :strength_ratio,
    :agility_ratio,
    :description,
    :style,
    :gameplay,
    keyword_init: true
  )

  CHOICES = [
    Choice.new(
      key: "small_sword",
      name: "無銘の直剣",
      weapon_type: "片手直剣",
      rarity: "common",
      attack_power: 6,
      durability: 200,
      max_durability: 200,
      hp_bonus: 0,
      strength_bonus: 1,
      agility_bonus: 0,
      critical_rate: 5,
      part_break_power: 100,
      attack_attributes: "斬撃",
      weight: 3.8,
      strength_ratio: 70,
      agility_ratio: 30,
      description: "銘の無い片手直剣。壊れにくく、攻撃と防御の判断を覚えやすい。地味な見た目に反して芯は良い。",
      style: "標準型",
      gameplay: "安定した斬撃で戦う基本スタイル。迷ったらこれを選ぶと、命中・火力・耐久のバランスがよく進められます。"
    ),
    Choice.new(
      key: "small_rapier",
      name: "スモールレイピア",
      weapon_type: "細剣",
      rarity: "common",
      attack_power: 5,
      durability: 180,
      max_durability: 180,
      hp_bonus: 0,
      strength_bonus: 0,
      agility_bonus: 1,
      critical_rate: 9,
      part_break_power: 90,
      attack_attributes: "刺突",
      weight: 2.9,
      strength_ratio: 30,
      agility_ratio: 70,
      description: "初心者用の細剣。軽さと会心率に優れ、一点突破の刺突に向く。",
      style: "速度型",
      gameplay: "敏捷を活かして手数とクリティカルを狙うスタイル。軽快に攻めたい人や、刺突弱点を突く戦いが好きな人向けです。"
    )
  ].freeze

  def self.all
    CHOICES
  end

  def self.find(key)
    all.find { |choice| choice.key == key.to_s }
  end
end
