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
    assert_match(/\[reward\].*刻銭獲得！.*経験値を 10 獲得した！.*\[\/reward\]/m, result.message)
  end

  test "sword skill requires equipped weapon" do
    player = players(:one)
    player.weapons.destroy_all
    mob = Mob.create!(name: "錬技制限テストmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "カデーレ",
      damage_multiplier: 150,
      durability_cost: 2,
      skill_gain: 3,
      stiffness: true,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃"
    )

    assert_equal :error, result.status
    assert_includes result.message, "武器を装備していないため、錬技は使用できません。"
  end

  test "near reach weapon closes from middle distance before attacking" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "射程確認剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    BuffEffectService.apply_battle_effect!(player, "test_sure_hit", { sure_hit: true }, turns: 1)
    mob = Mob.create!(name: "距離確認mob", hp: 50, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 50)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 50, enemy_level: 1, position: 1, distance: "middle")

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      target_enemy_id: enemy.id,
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
    assert_includes result.message, "接近した"
    assert_equal "near", enemy.reload.distance
    assert_operator enemy.enemy_hp, :<, 50
  end

  test "near reach weapon cannot close from far distance and attack" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "遠距離確認剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "遠距離確認mob", hp: 50, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 50)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 50, enemy_level: 1, position: 1, distance: "far")

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      target_enemy_id: enemy.id,
      label: "通常攻撃",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 0,
      stiffness: false,
      hits: 1,
      sword_skill: false,
      attack_attribute: "斬撃"
    )

    assert_equal :error, result.status
    assert_includes result.message, "距離が遠く攻撃が届きません"
    assert_equal "far", enemy.reload.distance
    assert_equal 50, enemy.enemy_hp
  end

  test "player hunt ambush opening closes from far distance before attacking once" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "狩り奇襲剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    BuffEffectService.apply_battle_effect!(player, "test_sure_hit", { sure_hit: true }, turns: 1)
    mob = Mob.create!(name: "狩り奇襲mob", hp: 80, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 80, ambush: true, initiative_type: "player_ambush")
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 80, enemy_level: 1, position: 1, distance: "far")

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      target_enemy_id: enemy.id,
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
    assert_includes result.message, "遠距離→近距離"
    assert_equal "near", enemy.reload.distance
    assert_not battle.reload.ambush?
  end

  test "throwing item cannot be used at near distance" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    item = player.items.create!(name: "石ころ", category: "gathered", quantity: 1)
    mob = Mob.create!(name: "近距離投擲確認mob", hp: 50, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 50)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 50, enemy_level: 1, position: 1, distance: "near")

    result = BattleService.resolve_throw_item!(
      battle: battle,
      player: player,
      item_id: item.id,
      mob_part_id: nil,
      target_enemy_id: enemy.id
    )

    assert_equal :error, result.status
    assert_includes result.message, "近距離では投擲できません"
    assert_equal 1, item.reload.quantity
  end

  test "throwing item damages target and consumes one item at middle distance" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 20, agility: 20)
    item = player.items.create!(name: "石ころ", category: "gathered", quantity: 1)
    mob = Mob.create!(name: "投擲確認mob", hp: 50, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 50)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 50, enemy_level: 1, position: 1, distance: "middle")

    rolls = [99, 0, 100, 99, 99, 1]
    BattleService.singleton_class.define_method(:rand) do |range = nil|
      value = rolls.shift || (range.is_a?(Range) ? range.begin : 0)
      range.is_a?(Range) ? value.clamp(range.begin, range.end) : value
    end
    begin
      result = BattleService.resolve_throw_item!(
        battle: battle,
        player: player,
        item_id: item.id,
        mob_part_id: nil,
        target_enemy_id: enemy.id
      )
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "石ころを投擲した"
    assert_operator enemy.reload.enemy_hp, :<, 50
    assert_nil Item.find_by(id: item.id)
    assert_equal 100, player.reload.hp
  end

  test "throwing item only allows non target enemies to counterattack" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 20, agility: 20)
    item = player.items.create!(name: "石ころ", category: "gathered", quantity: 1)
    target_mob = Mob.create!(name: "投擲対象mob", hp: 50, atk: 30, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    other_mob = Mob.create!(name: "反撃確認mob", hp: 50, atk: 30, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: target_mob, enemy_hp: 50)
    target = battle.battle_enemies.create!(mob: target_mob, enemy_hp: 50, enemy_level: 1, position: 1, distance: "middle")
    battle.battle_enemies.create!(mob: other_mob, enemy_hp: 50, enemy_level: 1, position: 2, distance: "near")

    rolls = [99, 0, 100, 99, 99, 1]
    BattleService.singleton_class.define_method(:rand) do |range = nil|
      value = rolls.shift || (range.is_a?(Range) ? range.begin : 0)
      range.is_a?(Range) ? value.clamp(range.begin, range.end) : value
    end
    begin
      result = BattleService.resolve_throw_item!(
        battle: battle,
        player: player,
        item_id: item.id,
        mob_part_id: nil,
        target_enemy_id: target.id
      )
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "反撃確認mobの攻撃"
    assert_operator player.reload.hp, :<, 100
  end

  test "backstep is blocked when surrounded by nearby enemies" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 10)
    mob = Mob.create!(name: "包囲確認mob", hp: 30, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 30)
    3.times do |index|
      battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: index + 1, distance: "near")
    end

    result = BattleService.resolve_backstep!(player, battle, target_enemy_id: battle.battle_enemies.first.id)

    assert_equal :error, result.status
    assert_includes result.message, "囲まれていて距離を取れません"
  end

  test "successful backstep makes target enemy miss its immediate action" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 20)
    mob = Mob.create!(name: "後退確認mob", hp: 30, atk: 20, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 30)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1, distance: "near")

    BattleService.singleton_class.define_method(:rand) { |_range| 0 }
    begin
      result = BattleService.resolve_backstep!(player, battle, target_enemy_id: enemy.id)

      assert_equal :ok, result.status
      assert_includes result.message, "バックステップ"
      assert_includes result.message, "踏み込みが間に合わなかった"
      assert_equal "middle", enemy.reload.distance
      assert_equal 100, player.reload.hp
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "evasive action raises evasion chance and consumes enemy attack turn" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 20)
    mob = Mob.create!(name: "回避確認mob", hp: 30, atk: 20, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 30)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1, distance: "near")

    BattleService.singleton_class.define_method(:rand) { |_range| 0 }
    begin
      result = BattleService.resolve_evasive_action!(player, battle)

      assert_equal :ok, result.status
      assert_includes result.message, "回避行動を取った"
      assert_includes result.message, "回避した"
      assert_equal 100, player.reload.hp
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "sword skill starts lockout before individual cooldown and blocks all sword skills" do
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
      label: "カデーレ",
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
    assert_equal 1, player.reload.sword_skill_lockout_turns
    assert_equal 0, player.sword_skill_cooldown("vertical")

    blocked = BattleService.resolve_player_attack!(
      battle: battle.reload,
      player: player,
      mob_part_id: nil,
      label: "セカーレ",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 1,
      stiffness: false,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃",
      skill_key: "horizontal",
      cooldown: 1
    )

    assert_equal :error, blocked.status
    assert_includes blocked.message, "錬技発動後の反動"
    assert_equal 99, weapon.reload.durability

    normal_attack = BattleService.resolve_player_attack!(
      battle: battle.reload,
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

    assert_equal :ok, normal_attack.status
    assert_equal 0, player.reload.sword_skill_lockout_turns
    assert_equal 1, player.sword_skill_cooldown("vertical")
  end

  test "sword skill only receives enemy attack during stiffness" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "硬直テスト剣", weapon_type: "片手直剣", attack_power: 1, durability: 100, max_durability: 100, equipped: true)
    BuffEffectService.apply_battle_effect!(player, "test_sure_hit", { sure_hit: true }, turns: 1)
    mob = Mob.create!(name: "硬直反撃テストmob", hp: 999, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 999)

    result = BattleService.resolve_player_attack!(
      battle: battle,
      player: player,
      mob_part_id: nil,
      label: "カデーレ",
      damage_multiplier: 100,
      durability_cost: 1,
      skill_gain: 1,
      stiffness: true,
      hits: 1,
      sword_skill: true,
      attack_attribute: "斬撃",
      skill_key: "vertical",
      cooldown: 1
    )

    assert_equal :ok, result.status
    assert_not_includes result.message, "[enemy]硬直反撃テストmobの攻撃！"
    assert_includes result.message, "[enemy]錬技後の硬直中、硬直反撃テストmobの攻撃！"
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

  test "sword skill lockout pauses existing cooldowns until pending cooldown starts" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "CT停止テスト剣", weapon_type: "片手直剣", attack_power: 1, durability: 100, max_durability: 100, equipped: true)
    player.start_sword_skill_cooldown!("horizontal", 2)
    player.start_sword_skill_lockout!("vertical", 1)
    player.save!
    mob = Mob.create!(name: "CT停止テストmob", hp: 999, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
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
    assert_equal 0, player.reload.sword_skill_lockout_turns
    assert_equal 2, player.sword_skill_cooldown("horizontal")
    assert_equal 1, player.sword_skill_cooldown("vertical")
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

  test "guarded player attack does not roll miss after guard succeeds" do
    player = players(:one)
    player.update!(strength: 10, agility: 1)
    weapon = player.weapons.create!(name: "ガード確認剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "ガード確認mob", hp: 100, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    weak_part = mob.mob_parts.create!(name: "核", damage_multiplier: 100, weakness: true)
    mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)
    rolls = 0

    BattleService.singleton_class.define_method(:rand) do |range|
      rolls += 1
      rolls == 1 ? 0 : (range.is_a?(Range) ? range.end : 99)
    end
    begin
      result = BattleService.resolve_hit!(
        player: player,
        weapon: weapon,
        battle_enemy: enemy,
        mob_part_id: weak_part.id,
        damage_multiplier: 100,
        attack_attribute: "斬撃"
      )

      assert_includes result, "胴体で防がれた！"
      assert_includes result, "胴体へ"
      assert_not_includes result, "ミス"
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "missed player attack says enemy dodged" do
    player = players(:one)
    player.update!(strength: 10, agility: 1)
    weapon = player.weapons.create!(name: "回避表示確認剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "回避表示mob", hp: 100, atk: 1, rarity: "normal", level: 1, agility: 50, durability: 1, exp_reward: 10, flee_rate: 0)
    part = mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 99 }
    begin
      result = BattleService.resolve_hit!(
        player: player,
        weapon: weapon,
        battle_enemy: enemy,
        mob_part_id: part.id,
        damage_multiplier: 100,
        attack_attribute: "斬撃"
      )

      assert_includes result, "躱された！"
      assert_not_includes result, "ミス"
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
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

  test "battle potion healing resolves over five player turns" do
    player = players(:one)
    player.update!(hp: 40, max_hp: 200)
    player.items.create!(name: "ポーション", category: "healing", quantity: 1)
    expected_hp = player.hp + ItemService.potion_heal_amount(player)
    mob = Mob.create!(name: "ポーション回復確認mob", hp: 999, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 999)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 999, enemy_level: 1, position: 1)

    result = ItemService.start_battle_potion_healing!(player)

    assert_equal :ok, result.status
    assert_equal 40, player.reload.hp
    assert player.potion_healing?

    5.times do
      messages = BattleService.apply_battle_turn_start_effects!(player, battle)
      player.save!
      assert messages.any? { |message| message.include?("ポーションの回復効果") }
    end

    assert_equal expected_hp, player.reload.hp
    assert_not player.potion_healing?
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

  test "shield defense applies only while defending" do
    player = players(:one)
    player.armors.destroy_all
    body = player.armors.create!(name: "防御用胴", armor_type: "body", slot: "body", rarity: "common", defense: 10, durability: 100, max_durability: 100, equipped: true)
    shield = player.armors.create!(name: "防御用盾", armor_type: "盾", slot: "shield", rarity: "common", defense: 90, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "盾計算mob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 1)

    normal_damage = BattleService.apply_enemy_damage_mitigation(player, enemy, 100)

    assert_equal 50, normal_damage
    assert_equal 99, body.reload.durability
    assert_equal 100, shield.reload.durability

    guarded_damage = BattleService.apply_enemy_damage_mitigation(player, enemy, 100, shield_guard: true)

    assert_equal 10, guarded_damage
    assert_equal 99, body.reload.durability
    assert_equal 99, shield.reload.durability
  end

  test "defense action requires an equipped shield" do
    player = players(:one)
    player.armors.where(slot: "shield").destroy_all
    mob = Mob.create!(name: "盾なし防御mob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)

    result = BattleService.resolve_defense!(player, battle)

    assert_equal :error, result.status
    assert_includes result.message, "盾を装備していないため、防御できません。"
  end

  test "successful parry staggers enemy and skips its next action" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 50, agility: 10)
    weapon = player.weapons.create!(name: "パリィ成功剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "パリィ成功mob", hp: 10, atk: 10, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |_arg = nil| 0 }
    begin
      result = BattleService.resolve_parry!(player, battle)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "パリィした"
    assert BattleService.enemy_sword_skill_stiffness?(enemy.reload)
    assert_operator weapon.reload.durability, :>, 90

    before_hp = player.reload.hp
    enemy_result = BattleService.apply_enemy_attack!(player, battle)

    assert_includes enemy_result.message, "体勢を崩して動けない"
    assert_equal before_hp, player.reload.hp
  end

  test "failed parry consumes heavy durability and receives critical damage" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 1, agility: 10)
    weapon = player.weapons.create!(name: "盾用パリィ剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    shield = player.armors.create!(name: "パリィ失敗盾", armor_type: "盾", slot: "shield", defense: 2, durability: 20, max_durability: 20, equipped: true)
    mob = Mob.create!(name: "パリィ失敗mob", hp: 10, atk: 30, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) do |arg = nil|
      arg.is_a?(Range) ? arg.end : 99
    end
    begin
      result = BattleService.resolve_parry!(player, battle)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "パリィに失敗した"
    assert_includes result.message, "クリティカル"
    assert_equal 0, shield.reload.durability
    assert_equal 100, weapon.reload.durability
    assert_operator player.reload.hp, :<, 50
  end

  test "parry requires one on one combat" do
    player = players(:one)
    player.weapons.create!(name: "多対一パリィ剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "多対一パリィmob", hp: 10, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    battle = player.battles.create!(mob: mob, enemy_hp: 10)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 1)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 10, enemy_level: 1, position: 2)

    result = BattleService.resolve_parry!(player, battle)

    assert_equal :error, result.status
    assert_includes result.message, "敵と1対1"
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

  test "default mob status attacks are limited to intended enemies" do
    assert_empty Mob.new(name: "スライム").status_attacks
    assert_empty Mob.new(name: "蒼狼フェンリル").status_attacks
    assert_equal({ "poison" => 10 }, Mob.new(name: "変異スライム").status_attacks)
    assert_equal({ "paralysis" => 14 }, Mob.new(name: "フォレストワスプ").status_attacks)
  end

  test "mob status accumulation amount varies per hit" do
    BattleService.singleton_class.define_method(:rand) { |range| range.begin }
    begin
      assert_equal 7.5, BattleService.varied_status_attack_amount(10)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    BattleService.singleton_class.define_method(:rand) { |range| range.end }
    begin
      assert_equal 12.5, BattleService.varied_status_attack_amount(10)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "armed enemies only use learned sword skills" do
    mob = Mob.create!(name: "武装スキルmob", hp: 30, atk: 10, rarity: "normal", level: 30, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0, enemy_sword_skill_keys: "vertical|horizontal")
    mob.weapons.create!(name: "敵用ショートソード", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 30, position: 1)

    skill_names = BattleService.enemy_sword_skills_for(enemy).map(&:name)

    assert_equal ["カデーレ", "セカーレ"], skill_names
    assert_not_includes skill_names, "ビス・カデーレ"
    assert_not_includes skill_names, "ビス・セカーレ"
  end

  test "armed enemies without learned sword skills do not use sword skills" do
    mob = Mob.create!(name: "未習得武装mob", hp: 30, atk: 10, rarity: "normal", level: 50, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    mob.weapons.create!(name: "未習得敵用剣", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    enemy = battles(:one).battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 50, position: 1)

    assert_empty BattleService.enemy_sword_skills_for(enemy)
  end

  test "bosses use available sword skills without random rate gate" do
    mob = Mob.create!(name: "武装ボスmob", hp: 30, atk: 10, rarity: "boss", boss_type: "area_boss", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0, enemy_sword_skill_keys: "vertical|horizontal")
    mob.weapons.create!(name: "ボス用ショートソード", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = battles(:one)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 99 }
    begin
      skill = BattleService.enemy_sword_skill_for(enemy)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_includes ["カデーレ", "セカーレ"], skill.name
  end

  test "configured enemy sword skill keys define learned skills for future floor bosses" do
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

    assert_equal ["ビス・セカーレ"], skill_names
  end

  test "armed enemy cannot use sword skills when weapon arm is broken" do
    mob = Mob.create!(
      name: "腕破壊スキルmob",
      hp: 30,
      atk: 10,
      rarity: "boss",
      boss_type: "floor_boss",
      level: 1,
      agility: 1,
      durability: 1,
      exp_reward: 10,
      flee_rate: 0,
      enemy_sword_skill_keys: "vertical"
    )
    mob.weapons.create!(name: "腕破壊テスト剣", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    arm = mob.mob_parts.create!(name: "腕", damage_multiplier: 80, weakness: false, max_durability: 10, break_effect: "strength_down")
    enemy = battles(:one).battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1)
    enemy.part_states = { arm.id.to_s => { durability: 0, broken: true } }.to_json
    enemy.save!

    assert BattleService.enemy_weapon_arm_broken?(enemy)
    assert_empty BattleService.enemy_sword_skills_for(enemy)
    assert_nil BattleService.enemy_sword_skill_for(enemy)
  end

  test "armed enemy randomly uses a sword skill in battle" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 0)
    player.weapons.destroy_all
    mob = Mob.create!(name: "錬技使用mob", hp: 30, atk: 10, rarity: "normal", level: 10, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0, enemy_sword_skill_keys: "vertical|horizontal")
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
    assert_match(/錬技使用mobの(カデーレ|セカーレ)！/, result.message)
    assert_operator player.reload.hp, :<, 100
  end

  test "enemy sword skill stiffness makes next player attack sure hit with higher critical chance" do
    player = players(:one)
    player.update!(strength: 10, agility: 1)
    weapon = player.weapons.create!(name: "硬直追撃剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true, critical_rate: 0)
    mob = Mob.create!(name: "敵硬直テストmob", hp: 100, atk: 1, rarity: "normal", level: 1, agility: 20, durability: 1, exp_reward: 10, flee_rate: 0)
    part = mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false, max_durability: 999)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)
    BattleService.mark_enemy_sword_skill_stiffness!(enemy, SkillCatalog.find("vertical"))
    enemy.save!

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 10 }
    begin
      assert BattleService.player_attack_hit?(player, enemy, part)
      assert BattleService.critical_hit?(player, weapon, enemy, part, 1)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end
  end

  test "player weapon guard against enemy sword skill causes knockback without stiffness" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "受け止め剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "武器受け敵mob", hp: 30, atk: 10, rarity: "boss", boss_type: "area_boss", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0, enemy_sword_skill_keys: "vertical")
    mob.weapons.create!(name: "敵錬技剣", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    battle = player.battles.create!(mob: mob, enemy_hp: 30)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 30, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 0 }
    begin
      result = BattleService.apply_enemy_attack!(player, battle, allow_evasion: false)
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "受け止め剣で弾いた！"
    assert_includes result.message, "ノックバックが発生"
    assert_equal 100, player.reload.hp
    assert_not BattleService.enemy_sword_skill_stiffness?(enemy.reload)
  end

  test "enemy weapon block against player sword skill causes knockback and skips stiffness attack" do
    player = players(:one)
    player.update!(hp: 100, max_hp: 100, strength: 10, agility: 10)
    player.weapons.destroy_all
    player.weapons.create!(name: "ノックバック確認剣", weapon_type: "片手直剣", attack_power: 10, durability: 100, max_durability: 100, equipped: true)
    mob = Mob.create!(name: "敵武器防御mob", hp: 100, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    mob.weapons.create!(name: "敵防御剣", weapon_type: "片手直剣", rarity: "common", attack_power: 5, durability: 100, max_durability: 100, attack_attributes: "斬撃")
    weak_part = mob.mob_parts.create!(name: "核", damage_multiplier: 100, weakness: true)
    battle = player.battles.create!(mob: mob, enemy_hp: 100)
    battle.battle_enemies.create!(mob: mob, enemy_hp: 100, enemy_level: 1, position: 1)

    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 0 }
    begin
      result = BattleService.resolve_player_attack!(
        battle: battle,
        player: player,
        mob_part_id: weak_part.id,
        label: "カデーレ",
        damage_multiplier: 100,
        durability_cost: 1,
        skill_gain: 1,
        stiffness: true,
        hits: 1,
        sword_skill: true,
        attack_attribute: "斬撃",
        skill_key: "vertical",
        cooldown: 1
      )
    ensure
      BattleService.singleton_class.remove_method(:rand)
    end

    assert_equal :ok, result.status
    assert_includes result.message, "敵防御剣で弾かれた！"
    assert_includes result.message, "ノックバックが発生"
    assert_not_includes result.message, "錬技後の硬直中"
  end

  test "resolve_hit! records critical hits and kills for evolvable-origin weapons" do
    player = players(:one)
    player.update!(strength: 10, agility: 1)
    weapon = player.weapons.create!(name: "進化追跡剣", weapon_type: "片手直剣", attack_power: 100, durability: 100, max_durability: 100, equipped: true, origin: "starter")
    mob = Mob.create!(name: "進化追跡mob", hp: 1000, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    part = mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false)
    battle = player.battles.create!(mob: mob, enemy_hp: 1000)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 1000, enemy_level: 1, position: 1)

    original_critical_hit = BattleService.method(:critical_hit?)
    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 0 }
    BattleService.define_singleton_method(:critical_hit?) { |*| true }
    begin
      BattleService.resolve_hit!(
        player: player, weapon: weapon, battle_enemy: enemy, mob_part_id: part.id,
        damage_multiplier: 100, attack_attribute: "斬撃"
      )
    ensure
      BattleService.singleton_class.remove_method(:rand)
      BattleService.define_singleton_method(:critical_hit?, original_critical_hit)
    end

    assert_equal 1, weapon.reload.critical_hit_count
    assert_equal 0, weapon.kill_count
  end

  test "resolve_hit! records a kill without a critical hit and leaves non-evolvable weapons untouched" do
    player = players(:one)
    player.update!(strength: 10, agility: 1)
    weapon = player.weapons.create!(name: "撃破追跡剣", weapon_type: "片手直剣", attack_power: 100, durability: 100, max_durability: 100, equipped: true, origin: "shop")
    mob = Mob.create!(name: "撃破追跡mob", hp: 1, atk: 1, rarity: "normal", level: 1, agility: 1, durability: 1, exp_reward: 10, flee_rate: 0)
    part = mob.mob_parts.create!(name: "胴体", damage_multiplier: 100, weakness: false)
    battle = player.battles.create!(mob: mob, enemy_hp: 1)
    enemy = battle.battle_enemies.create!(mob: mob, enemy_hp: 1, enemy_level: 1, position: 1)

    original_critical_hit = BattleService.method(:critical_hit?)
    BattleService.singleton_class.define_method(:rand) { |arg = nil| arg.is_a?(Range) ? arg.end : 0 }
    BattleService.define_singleton_method(:critical_hit?) { |*| false }
    begin
      BattleService.resolve_hit!(
        player: player, weapon: weapon, battle_enemy: enemy, mob_part_id: part.id,
        damage_multiplier: 100, attack_attribute: "斬撃"
      )
    ensure
      BattleService.singleton_class.remove_method(:rand)
      BattleService.define_singleton_method(:critical_hit?, original_critical_hit)
    end

    assert_equal 0, weapon.reload.critical_hit_count
    assert_equal 0, weapon.kill_count
  end
end
