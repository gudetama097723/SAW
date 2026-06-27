class NpcQuestCsvImporter
  DEFAULT_PATH = Rails.root.join("db", "seeds", "npc_quests.csv")

  Result = Struct.new(:created, :updated, keyword_init: true) do
    def total = created + updated
  end

  def initialize(path = DEFAULT_PATH)
    @path = path
  end

  def import!
    result = Result.new(created: 0, updated: 0)

    SimpleCsv.foreach(@path) do |row|
      npc   = Npc.find_by!(code: required(row, "npc_code"))
      quest = NpcQuest.find_or_initialize_by(code: required(row, "code"))

      quest.assign_attributes(
        npc:                        npc,
        name:                       required(row, "name"),
        description:                row["description"].presence,
        start_conditions_json:      row["start_conditions_json"].presence || "{}",
        completion_conditions_json: row["completion_conditions_json"].presence || "{}",
        reward_data:                row["reward_data"].presence || "{}",
        repeatable:                 boolean(row["repeatable"], default: false),
        sort_order:                 integer(row["sort_order"]) || 0,
        active:                     boolean(row["active"], default: true)
      )

      quest.new_record? ? result.created += 1 : result.updated += 1
      quest.save!
    end

    result
  end

  private

  def required(row, key)
    value = row[key].to_s.strip
    raise KeyError, "Missing required NPC quest CSV column: #{key}" if value.blank?
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
