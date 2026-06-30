class NpcAffinityCapRuleCsvImporter
  DEFAULT_PATH = Rails.root.join("db", "seeds", "npc_affinity_cap_rules.csv")

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
      rule = NpcAffinityCapRule.find_or_initialize_by(
        npc: npc,
        unlock_type: required(row, "unlock_type"),
        unlock_key: required(row, "unlock_key"),
        cap_value: integer(row["cap_value"]) || 60
      )
      rule.assign_attributes(
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
    raise KeyError, "Missing required NPC affinity cap rule CSV column: #{key}" if value.blank?

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
