class SpecialCraftedWeaponResolver
  # Hidden conditions can be added here without exposing fixed recipes to the UI.
  RULES = [].freeze

  def self.resolve(attributes:, materials:)
    RULES.find { |rule| rule.fetch(:condition).call(attributes, materials) }&.fetch(:name)
  end
end
