class AddBlacksmithFacilityToLocations < ActiveRecord::Migration[8.1]
  FACILITY_LOCATIONS = [ "はじまりの街", "ホルンカの村", "次の町", "トールバーナ" ].freeze

  def up
    add_column :locations, :has_blacksmith_facility, :boolean, default: false, null: false
    quoted_names = FACILITY_LOCATIONS.map { |name| connection.quote(name) }.join(", ")
    execute "UPDATE locations SET has_blacksmith_facility = 1 WHERE name IN (#{quoted_names})"
  end

  def down
    remove_column :locations, :has_blacksmith_facility
  end
end
