module GameHelper
  def signed_bonus(value)
    format("%+d", value.to_i)
  end

  def game_environment_classes(player, environment_location)
    [
      "game-shell",
      "game-time-#{time_period_key(player)}",
      "game-weather-#{weather_key(environment_location)}",
      "game-environment-#{environment_key(environment_location)}"
    ]
  end

  def time_period_label(player)
    GameTimeService.period_label(player)
  end

  private

  def time_period_key(player)
    GameTimeService.period_key(player)
  end

  def weather_key(location)
    key = location&.weather.to_s
    Location::WEATHER_LABELS.key?(key) ? key : "clear"
  end

  def environment_key(location)
    key = location&.environment.to_s
    Location::ENVIRONMENT_LABELS.key?(key) ? key : "normal"
  end
end
