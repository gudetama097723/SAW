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
end
