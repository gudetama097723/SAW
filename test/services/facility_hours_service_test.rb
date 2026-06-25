require "test_helper"

class FacilityHoursServiceTest < ActiveSupport::TestCase
  PlayerDouble = Struct.new(:current_time)

  test "inn is always open" do
    assert FacilityHoursService.open?("inn", PlayerDouble.new(0))
    assert FacilityHoursService.open?("inn", PlayerDouble.new(23 * 60 + 59))
  end

  test "item shop is open from 08:00 until before 20:00" do
    refute FacilityHoursService.open?("item_shop", PlayerDouble.new(7 * 60 + 59))
    assert FacilityHoursService.open?("item_shop", PlayerDouble.new(8 * 60))
    assert FacilityHoursService.open?("item_shop", PlayerDouble.new(19 * 60 + 59))
    refute FacilityHoursService.open?("item_shop", PlayerDouble.new(20 * 60))
  end

  test "blacksmith is open from 09:00 until before 18:00" do
    refute FacilityHoursService.open?("blacksmith", PlayerDouble.new(8 * 60 + 59))
    assert FacilityHoursService.open?("blacksmith", PlayerDouble.new(9 * 60))
    assert FacilityHoursService.open?("blacksmith", PlayerDouble.new(17 * 60 + 59))
    refute FacilityHoursService.open?("blacksmith", PlayerDouble.new(18 * 60))
  end

  test "formats hours text" do
    assert_equal "常時営業", FacilityHoursService.hours_text("inn")
    assert_equal "08:00-20:00", FacilityHoursService.hours_text("item_shop")
  end
end
