module GameHelper
  SAW_ASSET_EXTENSIONS = %w[webp png jpg jpeg gif].freeze

  def signed_bonus(value)
    format("%+d", value.to_i)
  end

  def formatted_attack_power(value, precision: 1)
    number_with_precision(value.to_f, precision: precision, strip_insignificant_zeros: false)
  end

  def formatted_attack_bonus_percent(weapon)
    number_with_precision(weapon.enhancement_attack_percent, precision: 1, strip_insignificant_zeros: true)
  end

  def formatted_enhancement_preview_value(preview, value)
    number_with_precision(value, precision: preview.precision, strip_insignificant_zeros: false)
  end

  def formatted_enhancement_preview_change(preview)
    change = preview.after_value - preview.before_value
    sign = change.positive? ? "+" : ""
    "#{sign}#{formatted_enhancement_preview_value(preview, change)}#{preview.unit}"
  end

  def game_environment_classes(player, environment_location)
    [
      "game-shell",
      "game-time-#{time_period_key(player)}",
      "game-weather-#{weather_key(environment_location)}",
      "game-environment-#{environment_key(environment_location)}"
    ]
  end

  def game_background_style(player, environment_location)
    image_path = saw_visual_asset_path(:background, game_background_asset_key(player, environment_location))
    return nil if image_path.blank?

    "--game-background-image: url('#{image_path}')"
  end

  def saw_visual_asset_path(kind, key)
    folder = saw_visual_asset_folder(kind)
    asset_keys = saw_asset_keys(key)
    return nil if folder.blank? || asset_keys.blank?

    asset_keys.each do |asset_key|
      SAW_ASSET_EXTENSIONS.each do |extension|
        logical_path = "saw/#{folder}/#{asset_key}.#{extension}"
        return asset_path(logical_path) if saw_asset_available?(logical_path)
      end
    end

    nil
  end

  def saw_visual_asset_key(record, fallback: nil)
    return saw_asset_key(fallback) if record.blank?

    if record.respond_to?(:code) && record.code.present?
      saw_asset_key(record.code)
    else
      saw_asset_key(record.respond_to?(:name) ? record.name : fallback)
    end
  end

  def saw_visual_placeholder_label(kind)
    {
      background: "BG",
      npc: "NPC",
      mob: "MOB",
      item: "ITEM",
      weapon: "WPN",
      armor: "ARM",
      skill: "SKILL",
      ui: "UI"
    }.fetch(kind.to_sym, "ART")
  end

  def time_period_label(player)
    GameTimeService.period_label(player)
  end

  def tagged_message_content(message, tag)
    message.to_s[/\[#{Regexp.escape(tag)}\](.*?)\[\/#{Regexp.escape(tag)}\]/m, 1]
  end

  def reward_message_text(message)
    tagged_message_content(message, "reward")
  end

  def reward_message_lines(message)
    reward_message_text(message).to_s
                                .gsub(/\[(?:levelup|boss)\](.*?)\[\/(?:levelup|boss)\]/m, "\\1")
                                .split("！")
                                .filter_map do |line|
      text = line.strip
      text.present? ? "#{text}！" : nil
    end
  end

  def treasure_reward_message_text(message)
    tagged_message_content(message, "treasure_reward")
  end

  def treasure_reward_message_lines(message)
    treasure_reward_message_text(message).to_s
                                         .split("。")
                                         .filter_map do |line|
      text = line.strip
      text.present? ? "#{text}。" : nil
    end
  end

  def battle_enemy_card_classes(player, enemy, selected: false)
    [
      "battle-enemy-card",
      ("battle-target-card-active" if selected),
      battle_enemy_threat_class(player, enemy)
    ].compact.join(" ")
  end

  def battle_enemy_threat_class(player, enemy)
    level_gap = enemy.effective_level.to_i - player.effective_level.to_i
    return nil if level_gap < 2

    case level_gap
    when 2..4
      "battle-enemy-threat-unease"
    when 5..7
      "battle-enemy-threat-danger"
    else
      "battle-enemy-threat-nightmare"
    end
  end

  def weapon_durability_state_class(weapon)
    return "weapon-durability-broken" if weapon.broken?

    case weapon.durability_percent
    when 0..10
      "weapon-durability-critical"
    when 11..25
      "weapon-durability-damaged"
    when 26..50
      "weapon-durability-worn"
    else
      "weapon-durability-good"
    end
  end

  def owned_item_quantity(player, name)
    player.items.where(name: name).sum(:quantity).to_i
  end

  def owned_weapon_count(player, name)
    player.weapons.where(name: name).count
  end

  def owned_armor_count(player, name)
    player.armors.where(name: name).count
  end

  private

  def game_background_asset_key(player, environment_location)
    location = environment_location || player&.location
    keys = [location&.name]
    keys << "safe_area" if location&.safe_area?
    keys << "floor_#{location.floor}" if location&.floor.present?
    keys
  end

  def saw_visual_asset_folder(kind)
    {
      background: "backgrounds",
      npc: "npcs",
      mob: "mobs",
      item: "items",
      weapon: "weapons",
      armor: "armors",
      skill: "skills",
      ui: "ui"
    }[kind.to_sym]
  end

  def saw_asset_key(value)
    saw_asset_keys(value).first
  end

  def saw_asset_keys(value)
    Array(value).filter_map do |candidate|
      candidate.to_s.downcase
               .unicode_normalize(:nfkc)
               .gsub(/[^\p{Alnum}]+/, "_")
               .gsub(/\A_+|_+\z/, "")
               .presence
    end
  end

  def saw_asset_available?(logical_path)
    if Rails.application.assets.respond_to?(:load_path)
      Rails.application.assets.load_path.find(logical_path).present?
    else
      asset_path(logical_path).present?
    end
  rescue StandardError
    false
  end

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
