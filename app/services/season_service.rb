class SeasonService
  SEASON_LABELS = {
    "spring" => "春",
    "summer" => "夏",
    "autumn" => "秋",
    "winter" => "冬"
  }.freeze

  SEASON_DESCRIPTIONS = {
    "spring" => "薬草や花系の採取に向き、穏やかな天候が多い季節。",
    "summer" => "虫系・水辺系モンスターが活発になり、灼熱環境の影響を受けやすい季節。",
    "autumn" => "木の実・キノコ系の採取に向き、商人NPCや収穫系クエストと相性が良い季節。",
    "winter" => "雪・吹雪が発生しやすく、極寒環境の影響を受けやすい季節。"
  }.freeze

  GATHERING_MODIFIERS = {
    "spring" => { default: 1.0, herb: 1.15, flower: 1.2 },
    "summer" => { default: 1.0, waterside: 1.1 },
    "autumn" => { default: 1.0, nut: 1.15, mushroom: 1.2 },
    "winter" => { default: 1.0 }
  }.freeze

  ENCOUNTER_MODIFIERS = {
    "spring" => { default: 1.0 },
    "summer" => { default: 1.0, insect: 1.15, waterside: 1.1 },
    "autumn" => { default: 1.0, merchant_event: 1.1, harvest_quest: 1.1 },
    "winter" => { default: 1.0, cold_event: 1.15 }
  }.freeze

  WEATHER_MODIFIERS = {
    "spring" => { default: 1.0, clear: 1.1, cloudy: 1.05, rain: 1.05 },
    "summer" => { default: 1.0, clear: 1.05, thunderstorm: 1.1 },
    "autumn" => { default: 1.0, clear: 1.05, fog: 1.05 },
    "winter" => { default: 1.0, snow: 1.25, blizzard: 1.2 }
  }.freeze

  ENVIRONMENT_MODIFIERS = {
    "spring" => { default: 1.0, normal: 1.05 },
    "summer" => { default: 1.0, extreme_heat: 1.2 },
    "autumn" => { default: 1.0, normal: 1.05 },
    "winter" => { default: 1.0, extreme_cold: 1.2, deep_fog_cold_event: 1.15 }
  }.freeze

  class << self
    def season_for_month(month)
      case normalize_month(month)
      when 3..5
        "spring"
      when 6..8
        "summer"
      when 9..11
        "autumn"
      else
        "winter"
      end
    end

    def label_for(season)
      SEASON_LABELS.fetch(normalize_season(season), SEASON_LABELS["spring"])
    end

    def description_for(season)
      SEASON_DESCRIPTIONS.fetch(normalize_season(season), SEASON_DESCRIPTIONS["spring"])
    end

    def gathering_modifier(season)
      GATHERING_MODIFIERS.fetch(normalize_season(season), GATHERING_MODIFIERS["spring"])
    end

    def encounter_modifier(season)
      ENCOUNTER_MODIFIERS.fetch(normalize_season(season), ENCOUNTER_MODIFIERS["spring"])
    end

    def weather_modifier(season)
      WEATHER_MODIFIERS.fetch(normalize_season(season), WEATHER_MODIFIERS["spring"])
    end

    def environment_modifier(season)
      ENVIRONMENT_MODIFIERS.fetch(normalize_season(season), ENVIRONMENT_MODIFIERS["spring"])
    end

    def scalar(modifier, key = :default)
      modifier.fetch(key.to_sym, modifier.fetch(key.to_s, modifier.fetch(:default, 1.0)))
    end

    private

    def normalize_month(month)
      value = month.to_i
      return value if (1..12).cover?(value)

      1
    end

    def normalize_season(season)
      SEASON_LABELS.key?(season.to_s) ? season.to_s : "spring"
    end
  end
end
