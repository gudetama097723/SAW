class Location < ApplicationRecord
  WEATHER_LABELS = {
    "clear" => "晴れ",
    "cloudy" => "曇り",
    "rain" => "雨",
    "thunderstorm" => "雷雨",
    "fog" => "霧",
    "snow" => "雪"
  }.freeze

  ENVIRONMENT_LABELS = {
    "normal" => "通常",
    "deep_fog" => "濃霧",
    "darkness" => "暗闇",
    "heavy_rain" => "豪雨",
    "strong_wind" => "強風",
    "toxic_mist" => "毒霧",
    "extreme_heat" => "灼熱",
    "extreme_cold" => "極寒"
  }.freeze

  WEATHER_DESCRIPTIONS = {
    "clear" => "空はよく晴れており、行動への影響はほとんどない。",
    "cloudy" => "雲が広がっているが、視界や探索への影響は小さい。",
    "rain" => "雨で足元が悪いが、水辺の素材は見つけやすい。",
    "thunderstorm" => "雷鳴が響き、移動や索敵に集中しづらい。",
    "fog" => "霧で視界が悪く、索敵やマッピングに影響する。",
    "snow" => "雪で足跡や地形が読みづらく、移動に注意が必要。"
  }.freeze

  ENVIRONMENT_DESCRIPTIONS = {
    "normal" => "特別な環境効果はない。",
    "deep_fog" => "濃い霧に包まれており、周囲の気配を読み取りづらい。",
    "darkness" => "暗闇に覆われ、視界が悪く、索敵やマッピングに影響する。",
    "heavy_rain" => "激しい雨が降り続き、足音や気配が雨音に紛れる。",
    "strong_wind" => "強い風が吹き、移動や遠方の確認が難しい。",
    "toxic_mist" => "毒性を帯びた霧が漂っている。将来的な継続ダメージや耐性判定に使える。",
    "extreme_heat" => "強烈な熱気に包まれている。将来的な装備や耐性条件に使える。",
    "extreme_cold" => "厳しい寒気に包まれている。将来的な装備や耐性条件に使える。"
  }.freeze

  WEATHER_MODIFIERS = {
    "clear" => { mapping: 1.0, encounter: 1.0, gathering: 1.0, stealth: 1.0, search: 1.0 },
    "cloudy" => { mapping: 1.0, encounter: 1.0, gathering: 1.0, stealth: 1.0, search: 1.0 },
    "rain" => { mapping: 0.95, encounter: 1.0, gathering: 1.05, stealth: 1.05, search: 0.95 },
    "thunderstorm" => { mapping: 0.9, encounter: 1.05, gathering: 0.95, stealth: 1.1, search: 0.9 },
    "fog" => { mapping: 0.9, encounter: 0.95, gathering: 1.0, stealth: 1.1, search: 0.85 },
    "snow" => { mapping: 0.95, encounter: 1.0, gathering: 0.95, stealth: 1.05, search: 0.95 }
  }.freeze

  ENVIRONMENT_MODIFIERS = {
    "normal" => { mapping: 1.0, encounter: 1.0, gathering: 1.0, stealth: 1.0, search: 1.0 },
    "deep_fog" => { mapping: 0.8, encounter: 0.9, gathering: 1.0, stealth: 1.2, search: 0.75 },
    "darkness" => { mapping: 0.85, encounter: 1.0, gathering: 0.95, stealth: 1.1, search: 0.8 },
    "heavy_rain" => { mapping: 0.9, encounter: 1.0, gathering: 1.1, stealth: 1.1, search: 0.9 },
    "strong_wind" => { mapping: 0.95, encounter: 1.0, gathering: 0.95, stealth: 0.95, search: 0.95 },
    "toxic_mist" => { mapping: 0.9, encounter: 1.0, gathering: 0.9, stealth: 1.05, search: 0.9 },
    "extreme_heat" => { mapping: 0.95, encounter: 1.0, gathering: 0.9, stealth: 1.0, search: 0.95 },
    "extreme_cold" => { mapping: 0.95, encounter: 1.0, gathering: 0.9, stealth: 1.0, search: 0.95 }
  }.freeze

  enum :weather, WEATHER_LABELS.keys.index_with(&:itself), prefix: true, validate: true
  enum :environment, ENVIRONMENT_LABELS.keys.index_with(&:itself), prefix: true, validate: true

  has_many :outgoing_routes, class_name: "Route", foreign_key: "from_location_id"
  has_many :incoming_routes, class_name: "Route", foreign_key: "to_location_id"
  has_many :field_areas, through: :outgoing_routes, source: :field_areas
  has_many :npcs, dependent: :nullify

  def weather_label
    WEATHER_LABELS.fetch(weather_value, WEATHER_LABELS["clear"])
  end

  def environment_label
    ENVIRONMENT_LABELS.fetch(environment_value, ENVIRONMENT_LABELS["normal"])
  end

  def weather_description
    WEATHER_DESCRIPTIONS.fetch(weather_value, WEATHER_DESCRIPTIONS["clear"])
  end

  def environment_description
    ENVIRONMENT_DESCRIPTIONS.fetch(environment_value, ENVIRONMENT_DESCRIPTIONS["normal"])
  end

  def mapping_modifier
    combined_modifier(:mapping)
  end

  def encounter_modifier
    combined_modifier(:encounter)
  end

  def gathering_modifier
    combined_modifier(:gathering)
  end

  def season_gathering_modifier(season)
    SeasonService.gathering_modifier(season)
  end

  def season_encounter_modifier(season)
    SeasonService.encounter_modifier(season)
  end

  def season_weather_modifier(season)
    SeasonService.weather_modifier(season)
  end

  def season_environment_modifier(season)
    SeasonService.environment_modifier(season)
  end

  def seasonal_context(season)
    {
      season: season.to_s,
      weather: weather_value,
      environment: environment_value,
      gathering_modifier: season_gathering_modifier(season),
      encounter_modifier: season_encounter_modifier(season),
      weather_modifier: season_weather_modifier(season),
      environment_modifier: season_environment_modifier(season)
    }
  end

  def stealth_modifier
    combined_modifier(:stealth)
  end

  def search_modifier
    combined_modifier(:search)
  end

  private

  def weather_value
    WEATHER_LABELS.key?(weather) ? weather : "clear"
  end

  def environment_value
    ENVIRONMENT_LABELS.key?(environment) ? environment : "normal"
  end

  def combined_modifier(key)
    weather_modifier = WEATHER_MODIFIERS.fetch(weather_value, WEATHER_MODIFIERS["clear"]).fetch(key)
    environment_modifier = ENVIRONMENT_MODIFIERS.fetch(environment_value, ENVIRONMENT_MODIFIERS["normal"]).fetch(key)
    (weather_modifier * environment_modifier).round(2)
  end
end
