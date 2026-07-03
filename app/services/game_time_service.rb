class GameTimeService
  PERIODS = {
    dawn: 300...480,
    day: 480...960,
    evening: 960...1140
  }.freeze

  LABELS = {
    dawn: "早朝",
    day: "昼",
    evening: "夕方",
    night: "夜"
  }.freeze

  def self.period_key(player_or_minutes)
    minutes =
      if player_or_minutes.respond_to?(:current_time)
        player_or_minutes.current_time.to_i
      else
        player_or_minutes.to_i
      end

    normalized = minutes % 1440
    PERIODS.find { |_key, range| range.cover?(normalized) }&.first || :night
  end

  def self.period_label(player_or_minutes)
    LABELS.fetch(period_key(player_or_minutes))
  end
end
