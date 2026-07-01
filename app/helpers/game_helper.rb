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
    {
      dawn: "早朝",
      day: "昼",
      evening: "夕方",
      night: "夜"
    }.fetch(time_period_key(player))
  end

  private

  def time_period_key(player)
    minutes = player.current_time.to_i % 1440

    case minutes
    when 300...480
      :dawn
    when 480...960
      :day
    when 960...1140
      :evening
    else
      :night
    end
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
