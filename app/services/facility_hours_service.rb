class FacilityHoursService
  HOURS = {
    "inn" => { label: "宿屋", always_open: true },
    "item_shop" => { label: "道具屋", opens_at: 8 * 60, closes_at: 20 * 60 },
    "blacksmith" => { label: "鍛冶屋", opens_at: 9 * 60, closes_at: 18 * 60 },
    "restaurant" => { label: "飲食店", opens_at: 7 * 60, closes_at: 22 * 60 }
  }.freeze

  def self.open?(facility_key, player)
    hours = HOURS[facility_key.to_s]
    return false unless hours
    return true if hours[:always_open]

    current_time = player.current_time.to_i % 1440
    opens_at = hours[:opens_at].to_i
    closes_at = hours[:closes_at].to_i

    if opens_at < closes_at
      current_time >= opens_at && current_time < closes_at
    else
      current_time >= opens_at || current_time < closes_at
    end
  end

  def self.label(facility_key)
    HOURS.dig(facility_key.to_s, :label).to_s
  end

  def self.hours_text(facility_key)
    hours = HOURS[facility_key.to_s]
    return "" unless hours
    return "常時営業" if hours[:always_open]

    "#{format_minutes(hours[:opens_at])}-#{format_minutes(hours[:closes_at])}"
  end

  def self.closed_message(facility_key, player)
    "#{label(facility_key)}は閉店中です。営業時間は#{hours_text(facility_key)}です。現在時刻: #{format_minutes(player.current_time)}"
  end

  def self.format_minutes(minutes)
    minutes = minutes.to_i % 1440
    format("%02d:%02d", minutes / 60, minutes % 60)
  end
end
