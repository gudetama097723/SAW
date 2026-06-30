class NpcAffinityRuleCsvImporter
  DEFAULT_PATH = Rails.root.join("db", "seeds", "npc_affinity_rules.csv")

  Result = Struct.new(:created, :updated, keyword_init: true) do
    def total
      created + updated
    end
  end

  def initialize(path = DEFAULT_PATH)
    @path = path
  end

  def import!
    result = Result.new(created: 0, updated: 0)

    SimpleCsv.foreach(@path) do |row|
      npc = Npc.find_by!(code: required(row, "npc_code"))
      rule = NpcAffinityRule.find_or_initialize_by(
        npc: npc,
        action_type: required(row, "action_type"),
        target_key: row["target_key"].presence
      )
      rule.assign_attributes(
        affinity_gain: integer(row["affinity_gain"]) || 0,
        daily_limit: boolean(row["daily_limit"], default: false),
        required_affinity: integer(row["required_affinity"]) || 0,
        conditions_json: row["conditions_json"].presence || "{}",
        active: boolean(row["active"], default: true),
        sort_order: integer(row["sort_order"]) || 0
      )

      rule.new_record? ? result.created += 1 : result.updated += 1
      rule.save!
    end

    result
  end

  private

  def required(row, key)
    value = row[key].to_s.strip
    raise KeyError, "Missing required NPC affinity rule CSV column: #{key}" if value.blank?

    value
  end

  def integer(value)
    value.present? ? value.to_i : nil
  end

  def boolean(value, default:)
    return default if value.blank?

    value.to_s.strip.downcase == "true"
  end
end
