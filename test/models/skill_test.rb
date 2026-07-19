require "test_helper"

class SkillTest < ActiveSupport::TestCase
  test "sword skill level reads current level data" do
    skill = skills(:one)
    skill.sword_skill_levels = { "vertical" => { "level" => 7, "exp" => 432 } }.to_json

    assert_equal 7, skill.sword_skill_level("vertical")
  end

  test "sword skill level still supports legacy numeric data" do
    skill = skills(:one)
    skill.sword_skill_levels = { "vertical" => 5 }.to_json

    assert_equal 5, skill.sword_skill_level("vertical")
  end

  test "skill mod points are earned every 50 proficiency and spent by learned ranks" do
    skill = skills(:one)
    skill.update!(name: "片手直剣", skill_category: "weapon", weapon_skill: true, proficiency: 250, learn_condition_data: "{}")

    assert_equal 5, skill.skill_mod_points_earned
    assert_equal 0, skill.skill_mod_points_spent
    assert skill.can_learn_skill_mod?("blade_line")

    assert_equal 1, skill.learn_skill_mod!("blade_line")
    assert_equal 1, skill.skill_mod_rank("blade_line")
    assert_equal 1, skill.skill_mod_points_spent
    assert_equal 4, skill.skill_mod_points_remaining

    assert_equal 2, skill.learn_skill_mod!("blade_line")
    assert_equal 3, skill.skill_mod_points_spent
    assert_equal 2, skill.skill_mod_points_remaining
  end

  test "skill mod cannot be learned when next rank cost exceeds remaining points" do
    skill = skills(:one)
    skill.update!(name: "片手直剣", skill_category: "weapon", weapon_skill: true, proficiency: 50, learn_condition_data: "{}")

    assert_not skill.can_learn_skill_mod?("cooldown_assist")
    assert_raises(ArgumentError) { skill.learn_skill_mod!("cooldown_assist") }
  end
end
