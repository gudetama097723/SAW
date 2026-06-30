class NpcCsvImporter
  DEFAULT_PATH = Rails.root.join("db", "seeds", "npcs.csv")

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
      npc = Npc.find_or_initialize_by(code: required(row, "code"))
      npc.assign_attributes(attributes_for(row))

      npc.new_record? ? result.created += 1 : result.updated += 1
      npc.save!
    end

    result
  end

  private

  def attributes_for(row)
    placement_type = required(row, "placement_type")

    {
      name: required(row, "name"),
      npc_type: row["npc_type"].presence || "general",
      placement_type: placement_type,
      location: location_for(row, placement_type),
      field_area: field_area_for(row, placement_type),
      facility_key: row["facility_key"].presence,
      dungeon_key: row["dungeon_key"].presence,
      position_key: row["position_key"].presence,
      sort_order: integer(row["sort_order"]) || 0,
      active: boolean(row["active"], default: true),
      description: row["description"].presence,
      metadata_json: row["metadata_json"].presence || "{}",
      discovery_rate: integer(row["discovery_rate"]) || 100,
      repeat_discovery_required: boolean(row["repeat_discovery_required"], default: false),
      discovery_conditions_json: row["discovery_conditions_json"].presence || "{}",
      initial_affinity_cap: integer(row["initial_affinity_cap"]) || 60
    }
  end

  def location_for(row, placement_type)
    return unless %w[town facility].include?(placement_type)

    Location.find_by!(name: required(row, "location"))
  end

  def field_area_for(row, placement_type)
    return unless placement_type == "field_area"

    route = Route.find_by!(name: required(row, "route"))
    route.field_areas.find_by!(name: required(row, "field_area"))
  end

  def required(row, key)
    value = row[key].to_s.strip
    raise KeyError, "Missing required NPC CSV column: #{key}" if value.blank?

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
