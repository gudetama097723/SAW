class GatheringCatalog
  Definition = Struct.new(:route_name, :item_name, :category, :weight, keyword_init: true)

  def self.roll_item(context)
    weighted_sample(definitions_for(context)) || Definition.new(route_name: "default", item_name: "薬草", category: "gathered", weight: 1)
  end

  def self.definitions_for(context)
    route_name = field_name_for(context)
    route_definitions = definitions.select { |definition| definition.route_name == route_name }
    route_definitions.presence || definitions.select { |definition| definition.route_name == "default" }
  end

  def self.definitions
    @definitions ||= load_definitions
  end

  def self.weighted_sample(candidates)
    weighted = candidates.flat_map do |candidate|
      [candidate] * [candidate.weight.to_i, 1].max
    end
    weighted.sample
  end

  def self.load_definitions
    path = Rails.root.join("db", "seeds", "gathering_items.csv")
    rows = []
    SimpleCsv.foreach(path) { |row| rows << row } if File.exist?(path)
    rows.map do |row|
      Definition.new(
        route_name: row["route"].presence || "default",
        item_name: row["item_name"],
        category: row["category"].presence || "gathered",
        weight: row["weight"].presence&.to_i || 1
      )
    end
  end

  def self.field_name_for(context)
    context.respond_to?(:field_route) ? context.field_route&.name.to_s : context&.name.to_s
  end
end
