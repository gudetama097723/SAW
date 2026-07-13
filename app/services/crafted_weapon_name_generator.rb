class CraftedWeaponNameGenerator
  ORE_PREFIXES = { "鉄鉱" => "アイアン", "鋭鉄鉱" => "シャープアイアン", "黒鋼鉱" => "ブラックスチール" }.freeze
  MATERIAL_PREFIXES = { "狼王の牙" => "ブラックファング", "コボルドの牙" => "ファング" }.freeze

  def self.call(template:, ore:, monster_material:)
    prefix = MATERIAL_PREFIXES[monster_material.name] || ORE_PREFIXES.fetch(ore.name, ore.name)
    "#{prefix}#{template.name_suffix}"
  end
end
