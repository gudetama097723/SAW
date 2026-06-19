class WeaponEvolutionRule < ApplicationRecord
  def required_materials
    JSON.parse(required_materials_data.presence || "{}")
  rescue JSON::ParserError
    {}
  end
end
