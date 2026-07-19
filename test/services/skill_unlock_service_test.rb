require "test_helper"

class SkillUnlockServiceTest < ActiveSupport::TestCase
  setup do
    @player = players(:one)
  end

  test "blacksmith skill unlocks once the maintenance kit has been used enough times" do
    @player.increment_skill_counter!(WeaponMaintenanceService::KIT_USE_COUNTER_KEY, WeaponMaintenanceService::KIT_SKILL_UNLOCK_USES - 1)
    assert_not_includes SkillUnlockService.available_for(@player).map(&:name), "鍛冶"

    @player.increment_skill_counter!(WeaponMaintenanceService::KIT_USE_COUNTER_KEY, 1)
    assert_includes SkillUnlockService.available_for(@player).map(&:name), "鍛冶"
  end

  test "blacksmith skill is not offered again once already learned" do
    @player.increment_skill_counter!(WeaponMaintenanceService::KIT_USE_COUNTER_KEY, WeaponMaintenanceService::KIT_SKILL_UNLOCK_USES)
    @player.skills.create!(name: "鍛冶", proficiency: 0, skill_exp: 0, skill_category: "passive")

    assert_not_includes SkillUnlockService.available_for(@player).map(&:name), "鍛冶"
  end
end
