class AddTemporaryBaseAllowedToLocations < ActiveRecord::Migration[8.1]
  TEMPORARY_BASE_LOCATIONS = [ "ヒルテンドルフ" ].freeze

  def up
    add_column :locations, :temporary_base_allowed, :boolean, default: false, null: false
    quoted_names = TEMPORARY_BASE_LOCATIONS.map { |name| connection.quote(name) }.join(", ")
    execute "UPDATE locations SET temporary_base_allowed = 1 WHERE name IN (#{quoted_names})"
  end

  def down
    remove_column :locations, :temporary_base_allowed
  end
end
