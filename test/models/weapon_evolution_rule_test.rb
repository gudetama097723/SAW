require "test_helper"

class WeaponEvolutionRuleTest < ActiveSupport::TestCase
  test "enhancement_maxed condition requires attempts to be spent without wasting any on failure" do
    rule = WeaponEvolutionRule.new(required_conditions_data: [ { "type" => "enhancement_maxed" } ].to_json)
    weapon = Weapon.new(enhance_limit: 1, enhance_attempts: 1, sharpness_level: 1)

    assert rule.conditions_met?(weapon)

    failed_weapon = Weapon.new(enhance_limit: 1, enhance_attempts: 1, sharpness_level: 0)
    assert_not rule.conditions_met?(failed_weapon)
  end

  test "enhancement_level condition checks a minimum total level" do
    rule = WeaponEvolutionRule.new(required_conditions_data: [ { "type" => "enhancement_level", "min" => 5 } ].to_json)
    weapon = Weapon.new(enhance_limit: 10, sharpness_level: 5)

    assert rule.conditions_met?(weapon)

    weapon.sharpness_level = 4
    assert_not rule.conditions_met?(weapon)
  end

  test "critical_hits and kills conditions must both be satisfied when combined" do
    rule = WeaponEvolutionRule.new(
      required_conditions_data: [
        { "type" => "critical_hits", "min" => 30 },
        { "type" => "kills", "min" => 50 }
      ].to_json
    )
    weapon = Weapon.new(critical_hit_count: 30, kill_count: 50)
    assert rule.conditions_met?(weapon)

    weapon.kill_count = 49
    assert_not rule.conditions_met?(weapon)
  end

  test "required_col and required_items are read from required_materials_data" do
    rule = WeaponEvolutionRule.new(required_materials_data: { "items" => { "硬い甲殻" => 3 }, "col" => 300 }.to_json)

    assert_equal 300, rule.required_col
    assert_equal({ "硬い甲殻" => 3 }, rule.required_items)
  end

  test "condition_summaries marks satisfied and unsatisfied conditions" do
    rule = WeaponEvolutionRule.new(
      required_conditions_data: [
        { "type" => "critical_hits", "min" => 10 },
        { "type" => "kills", "min" => 10 }
      ].to_json
    )
    weapon = Weapon.new(critical_hit_count: 10, kill_count: 0)

    summaries = rule.condition_summaries(weapon)
    assert_includes summaries, "○ クリティカルヒット10回以上"
    assert_includes summaries, "× モンスター撃破10体以上"
  end
end
