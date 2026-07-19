class SkillModCatalog
  ModDefinition = Struct.new(
    :key,
    :name,
    :skill_name,
    :category,
    :costs,
    :effect_summary,
    keyword_init: true
  ) do
    def max_rank
      costs.size
    end

    def cost_for_rank(rank)
      costs[rank.to_i - 1].to_i
    end

    def total_cost_for_rank(rank)
      costs.first(rank.to_i).sum
    end

    def next_cost(current_rank)
      cost_for_rank(current_rank.to_i + 1)
    end
  end

  ONE_HANDED_SWORD_MODS = [
    ModDefinition.new(key: "blade_line", name: "刃筋補正", skill_name: "片手直剣", category: "剣筋", costs: [1, 2, 3, 4, 5], effect_summary: "片手直剣の命中 +3ずつ"),
    ModDefinition.new(key: "light_grip", name: "軽い握り", skill_name: "片手直剣", category: "剣筋", costs: [1, 2, 3, 4, 5], effect_summary: "通常攻撃時、武器耐久消費を4%ずつ無効化"),
    ModDefinition.new(key: "first_reading", name: "見切りの初歩", skill_name: "片手直剣", category: "受け", costs: [1, 2, 3, 4, 5], effect_summary: "パリィ成功率 +3ずつ"),
    ModDefinition.new(key: "follow_through", name: "追い打ち", skill_name: "片手直剣", category: "剣筋", costs: [2, 3, 4], effect_summary: "体勢崩し中の敵への通常攻撃ダメージ +10%ずつ"),
    ModDefinition.new(key: "flowing_guard", name: "受け流しの型", skill_name: "片手直剣", category: "受け", costs: [2, 3, 4], effect_summary: "パリィ成功率 +5ずつ、失敗時の武器耐久消費 -10%ずつ"),
    ModDefinition.new(key: "nick_control", name: "刃こぼれ抑制", skill_name: "片手直剣", category: "錬技", costs: [2, 4], effect_summary: "錬技の耐久消費 -1ずつ。ただし最低1"),
    ModDefinition.new(key: "part_insight", name: "部位観測", skill_name: "片手直剣", category: "部位", costs: [2, 3, 4, 5], effect_summary: "弱点部位への命中 +5ずつ"),
    ModDefinition.new(key: "recoil_control", name: "反動制御", skill_name: "片手直剣", category: "錬技", costs: [3, 5, 7], effect_summary: "錬技後の硬直被ダメージ -8% / -14% / -20%"),
    ModDefinition.new(key: "cooldown_assist", name: "冷却補助", skill_name: "片手直剣", category: "錬技", costs: [4, 8], effect_summary: "片手直剣錬技の個別CT -1ずつ。最低1"),
    ModDefinition.new(key: "combo_maintenance", name: "連撃整備", skill_name: "片手直剣", category: "錬技", costs: [3, 4, 5], effect_summary: "2hit以上の錬技ダメージ +6%ずつ"),
    ModDefinition.new(key: "fracture_insight", name: "破断観測", skill_name: "片手直剣", category: "部位", costs: [3, 4, 5, 6], effect_summary: "部位耐久ダメージ +8%ずつ"),
    ModDefinition.new(key: "many_against_one", name: "一対多の構え", skill_name: "片手直剣", category: "剣筋", costs: [4, 5, 6], effect_summary: "複数敵戦闘時、命中と逃走率を少しずつ補正"),
    ModDefinition.new(key: "trajectory_memory", name: "軌道記憶", skill_name: "片手直剣", category: "錬技", costs: [4, 5, 6], effect_summary: "同じ敵に通常攻撃後、次の錬技命中 +8 / +13 / +18"),
    ModDefinition.new(key: "counter_reading", name: "反撃読み", skill_name: "片手直剣", category: "受け", costs: [5, 7], effect_summary: "パリィ成功後、次の片手直剣錬技の会心率 +12ずつ"),
    ModDefinition.new(key: "deep_breath", name: "深呼吸", skill_name: "片手直剣", category: "錬技", costs: [5, 7], effect_summary: "錬技を使わないターン終了時、最短CTをさらに1ずつ減少"),
    ModDefinition.new(key: "no_retreat", name: "不退転", skill_name: "片手直剣", category: "覚悟", costs: [6, 7, 8], effect_summary: "HP30%以下で命中 +4ずつ、被ダメージ -3%ずつ"),
    ModDefinition.new(key: "linked_break", name: "崩しの連理", skill_name: "片手直剣", category: "部位", costs: [7, 9], effect_summary: "部位破壊後、次の片手直剣錬技ダメージ +15%ずつ"),
    ModDefinition.new(key: "final_tuning", name: "終式調律", skill_name: "片手直剣", category: "錬技", costs: [8], effect_summary: "CT3以上の錬技CT -1、代わりに耐久消費 +1"),
    ModDefinition.new(key: "veteran_sword", name: "百戦の剣筋", skill_name: "片手直剣", category: "剣筋", costs: [8, 12], effect_summary: "片手直剣熟練度攻撃ボーナス上限 +5% / +10%"),
    ModDefinition.new(key: "true_straight", name: "真一文字", skill_name: "片手直剣", category: "部位", costs: [15], effect_summary: "単体錬技が弱点部位へ命中した時、30%で追加部位ダメージ"),
    ModDefinition.new(key: "unnamed_inheritance", name: "無銘継承", skill_name: "片手直剣", category: "覚悟", costs: [20], effect_summary: "通常攻撃・錬技・パリィ全体に小ボーナス")
  ].freeze

  MODS = ONE_HANDED_SWORD_MODS.freeze

  def self.all(skill_name = nil)
    skill_name.present? ? MODS.select { |mod| mod.skill_name == skill_name } : MODS
  end

  def self.find(key)
    MODS.find { |mod| mod.key == key.to_s }
  end
end
