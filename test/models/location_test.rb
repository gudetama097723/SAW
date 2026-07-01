require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "weather and environment labels fall back safely" do
    location = Location.new(weather: nil, environment: nil)

    assert_equal "晴れ", location.weather_label
    assert_equal "通常", location.environment_label
    assert_equal 1.0, location.mapping_modifier
  end

  test "combines weather and environment modifiers" do
    location = Location.new(weather: "fog", environment: "deep_fog")

    assert_equal "霧", location.weather_label
    assert_equal "濃霧", location.environment_label
    assert_equal 0.72, location.mapping_modifier
    assert_equal 1.32, location.stealth_modifier
  end

  test "seasonal context combines location weather and seasonal modifiers" do
    location = Location.new(weather: "fog", environment: "deep_fog")
    context = location.seasonal_context("autumn")

    assert_equal "fog", context[:weather]
    assert_equal "deep_fog", context[:environment]
    assert_equal 1.2, context[:gathering_modifier][:mushroom]
    assert_equal 1.05, context[:weather_modifier][:fog]
  end
end
