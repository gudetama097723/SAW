require "test_helper"

class BattleServiceTest < ActiveSupport::TestCase
  test "unarmed player can attack without equipped weapon" do
    player = players(:one)
    player.weapons.destroy_all
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    BuffEffectService.apply_battle_effect!(player, "test_sure_hit", { sure_hit: true }, turns: 1)
    mob = Mob.create!(name: "素手攻撃テストmob", hp: 1, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 1)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "素手攻撃",
      damage_multiplier: 100,
      durability_cost: 0,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false,
      attack_attribute: "打撃"
    )

    assert_equal :ok, result.status
    assert_includes result.message, "素手攻撃！"
    assert_match(/\[reward\].*コル獲得！.*経験値を 10 獲得した！.*\[\/reward\]/m, result.message)
  end

  test "sword skill requires equipped weapon" do
    player = players(:one)
    player.weapons.destroy_all
    mob = Mob.create!(name: "ソードスキル制限テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "バーチカル",
      damage_multiplier: 150,
      durability_cost: 2,
      skill_gain: 3,
      stiffness: true,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃"
    )

    assert_equal :error, result.status
    assert_includes result.message, "武器を装備していないため、ソードスキルは使用できません。"
  end

  test "sword skill starts individual cooldown and blocks repeated use" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    weapon = player.weapons.create!(name: "CTテスト剣", weapon_type: "片手直剣", attack_power: 1, durability: 100, max_durability: 100, equipped: true)
    player.skills.find_or_create_by!(name: "片手直剣") { |skill| skill.proficiency = 100; skill.skill_exp = 0; skill.skill_category = "weapon"; skill.weapon_skill = true }
    mob = Mob.create!(name: "CTテストmob", hp: 999, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 999)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "バーチカル",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 1,
      stiffness: false,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃",
      skill_key: "vertical",
      cooldown: 1
    )

    assert_equal :ok, result.status
    assert_equal 1, player.reload.sword_skill_cooldown("vertical")

    blocked = BattleService.resolve_player_attack!(
      battle: battle.reload,
      player: player,
      mob_part_id: nil,
      label: "バーチカル",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 1,
      stiffness: false,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃",
      skill_key: "vertical",
      cooldown: 1
    )

    assert_equal :error, blocked.status
    assert_includes blocked.message, "バーチカルはクールタイム中です。"
    assert_equal 99, weapon.reload.durability
  end

  test "normal attack reduces sword skill cooldown" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "CT減少テスト剣", weapon_type: "片手直剣", attack_power: 1, durability: 100, max_durability: 100, equipped: true)
    player.start_sword_skill_cooldown!("vertical", 1)
    player.save!
    mob = Mob.create!(name: "CT減少テストmob", hp: 999, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 999)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "通常攻撃",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false,
      attack_attribute: "斬撃"
    )

    assert_equal :ok, result.status
    assert_equal 0, player.reload.sword_skill_cooldown("vertical")
  end

  test "area attack can target arbitrary selected enemy ids" do
    player = players(:one)
    mob = Mob.create!(name: "複数選択テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    first = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 1)
    second = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 2)
    third = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 3)

    targets = BattleService.target_enemies_for(battle, nil, nil, true, "#{first.id},#{third.id}")

    assert_equal [first.id, third.id], targets.map(&:id)
    assert_not_includes targets.map(&:id), second.id
  end

  test "horizontal area skills are limited to two targets" do
    mob = Mob.create!(name: "範囲上限テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = players(:one).battles.create!(mob: mob, enemy_hp: 10)
    enemies = 4.times.map do |index|
      battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: index + 1)
    end

    targets = BattleService.target_enemies_for(
      battle,
      nil,
      nil,
      true,
      enemies.map(&:id).join(","),
      max_targets: SkillCatalog.find("horizontal").max_targets
    )

    assert_equal enemies.first(2).map(&:id), targets.map(&:id)
  end

  test "enemy with flee rate can flee instead of attacking" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100)
    mob = Mob.create!(name: "レア逃走mob", hp: 10, atk: 100, rarity: "rare", level: 1, agility: 1, durability: 1, exp_reward: 1000, flee_rate: 100)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

    assert_equal :ok, result.status
    assert_includes result.message, "レア逃走mobは逃走した！"
    assert_includes result.message, "敵はいなくなった。"
    assert_equal 100, player.reload.hp
    assert_not Battle.exists?(battle.id)
  end

  test "zero flee rate enemy attacks normally" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100)
    mob = Mob.create!(name: "通常mob", hp: 10, atk: 10, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

    assert_equal :ok, result.status
    assert_includes result.message, "通常mobの攻撃！"
    assert Battle.exists?(battle.id)
    assert_operator player.reload.hp, :<, 100
  end

  test "enemy damage uses proportional armor mitigation" do
    player = players(:one)
    player.armors.destroy_all
    player.armors.create!(name: "軽鎧", armor_type: "body", slot: "body", rarity: "common", defense: 2, equipped: true)
    player.update!(hp: 100, max_hp: 100, agility: 0)
    mob = Mob.create!(name: "防御計算mob", hp: 10, atk: 6, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    BattleService.singleton_class.define_method(:rand) { |range| range.end }
    begin
      result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)

      assert_equal :ok, result.status
      assert_equal 95, player.reload.hp
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "experience uses base reward and level gap only" do
    player = players(:one)
    player.update!(level: 1, exp: 0)
    mob = Mob.create!(name: "経験値計算mob", hp: 10, atk: 1, rarity: "normal", level: 3, agility: 1, durability: 1, exp_reward: 40, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 3, position: 1)

    assert_equal 52, BattleService.adjusted_exp_reward(player, enemy)
  end

  test "mob defeat drops can be filtered by enemy level" do
    mob = Mob.create!(name: "スライム", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 8, flee_rate: 0)

    low_level_names = MobDropCatalog.definitions_for(mob, enemy_level: 3).map(&:item_name)
    high_level_names = MobDropCatalog.definitions_for(mob, enemy_level: 16).map(&:item_name)

    assert_includes low_level_names, "スライムの粘液"
    assert_not_includes low_level_names, "スライムコア"
    assert_includes high_level_names, "スライムコア"
  end

  test "enemy sword skill proficiency scales by ten level tiers" do
    assert_equal 100, BattleService.enemy_sword_skill_proficiency_for_level(1)
    assert_equal 100, BattleService.enemy_sword_skill_proficiency_for_level(10)
    assert_equal 200, BattleService.enemy_sword_skill_proficiency_for_level(11)
    assert_equal 300, BattleService.enemy_sword_skill_proficiency_for_level(21)
  end

  test "armed enemies can use unlocked sword skills" do
    mob = Mob.create!(name: "武装スキルmob", hp: 30, atk: 10, rarity: "normal", level: 10, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    mob.weapons.create!(name: "敵用ショートソード", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 10, position: 1)

    skill_names = BattleService.enemy_sword_skills_for(enemy).map(&:name)

    assert_includes skill_names, "バーチカル"
    assert_includes skill_names, "バーチカルアーク"
    assert_not_includes skill_names, "ホリゾンタルアーク"
  end

  test "bosses use available sword skills without random rate gate" do
    mob = Mob.create!(name: "武装ボスmob", hp: 30, atk: 10, rarity: "boss", boss_type: "area_boss", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    mob.weapons.create!(name: "ボス用ショートソード", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 99 }
    begin
      skill = BattleService.enemy_sword_skill_for(enemy)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_includes ["バーチカル", "ホリゾンタル", "バーチカルアーク"], skill.name
  end

  test "configured enemy sword skill keys bypass proficiency for future floor bosses" do
    mob = Mob.create!(
      name: "階層ボステストmob",
      hp: 30,
      atk: 10,
      rarity: "boss",
      boss_type: "floor_boss",
      level: 1,
      agility: 1,
      durability: 1,
      exp_reward: 10,
      flee_rate: 0,
      enemy_sword_skill_keys: "horizontal_arc"
    )
    mob.weapons.create!(name: "階層ボス用剣", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    enemy = battles(:one).battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1)

    skill_names = BattleService.enemy_sword_skills_for(enemy).map(&:name)

    assert_equal ["ホリゾンタルアーク"], skill_names
  end

  test "armed enemy randomly uses a sword skill in battle" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 0)
    mob = Mob.create!(name: "ソードスキル使用mob", hp: 30, atk: 10, rarity: "normal", level: 10, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    mob.weapons.create!(name: "敵用ショートソード", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = player.battles.create!(mob: mob, enemy_hp: 30)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 10, position: 1)

    BattleService.singleton_class.define_method(:rand) do |arg = nil|
      arg.is_a?(Range) ? arg.end : 0
    end
    begin
      result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_match(/ソードスキル使用mobの(バーチカル|ホリゾンタル|バーチカルアーク)！/, result.message)
    assert_operator player.reload.hp, :<, 100
  end
end
