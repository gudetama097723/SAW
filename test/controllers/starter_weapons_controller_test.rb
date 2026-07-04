require "test_helper"

class StarterWeaponsControllerTest < ActionDispatch::IntegrationTest
  setup do
    location = Location.create!(name: "初期武器テスト町", floor: 1, danger_level: 0, safe_area: true)
    @user = User.create!(username: "starter_#{SecureRandom.hex(4)}", password: "password")
    @player = Player.create!(
      user: @user,
      name: "初期武器テスト",
      hp: 100,
      max_hp: 100,
      floor: 1,
      location: location
    )

    post login_path, params: { username: @user.username, password: "password" }
  end

  test "shows starter weapon choices and guidance" do
    get starter_weapon_path

    assert_response :success
    assert_includes response.body, "最初の武器を選択"
    assert_includes response.body, "スモールソード"
    assert_includes response.body, "スモールレイピア"
    assert_includes response.body, "ここで選ばなかった武器も、ゲーム開始後に入手・装備できます。"
    assert_includes response.body, "追加でスキル枠を1つ使用します。"
  end

  test "creates selected starter weapon and matching weapon skill" do
    post starter_weapon_path, params: { starter_weapon: "small_rapier" }

    assert_redirected_to game_path
    @player.reload
    weapon = @player.weapons.find_by(name: "スモールレイピア")
    assert weapon
    assert weapon.equipped?
    assert_equal "細剣", weapon.weapon_type
    assert @player.skills.exists?(name: "細剣", skill_category: "weapon", weapon_skill: true)
  end

  test "does not allow selecting a second starter weapon" do
    PlayerInitializer.choose_initial_weapon!(@player, StarterWeaponCatalog.find("small_sword"))

    get starter_weapon_path

    assert_redirected_to game_path
  end
end
