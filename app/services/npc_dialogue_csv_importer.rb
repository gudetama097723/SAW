class NpcDialogueCsvImporter
  DEFAULT_PATH = Rails.root.join("db", "seeds", "npc_dialogues.csv")

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
      dialogue = NpcDialogue.find_or_initialize_by(
        npc: npc,
        dialogue_type: required(row, "dialogue_type"),
        sequence: integer(row["sequence"]) || 0
      )
      dialogue.text = required(row, "text")
      dialogue.active = boolean(row["active"], default: true)

      dialogue.new_record? ? result.created += 1 : result.updated += 1
      dialogue.save!
    end

    result
  end

  private

  def required(row, key)
    value = row[key].to_s.strip
    raise KeyError, "Missing required NPC dialogue CSV column: #{key}" if value.blank?

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
