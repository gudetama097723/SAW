class ExpandBeginningTownHomeBaseStorageLimit < ActiveRecord::Migration[8.0]
  def up
    beginning_town_id = select_value("SELECT id FROM locations WHERE name = 'はじまりの街' LIMIT 1")
    return unless beginning_town_id

    execute <<~SQL.squish
      UPDATE player_bases
      SET storage_limit = 100
      WHERE location_id = #{quote(beginning_town_id)}
        AND base_type = 'home'
        AND storage_limit < 100
    SQL
  end

  def down
    beginning_town_id = select_value("SELECT id FROM locations WHERE name = 'はじまりの街' LIMIT 1")
    return unless beginning_town_id

    execute <<~SQL.squish
      UPDATE player_bases
      SET storage_limit = 30
      WHERE location_id = #{quote(beginning_town_id)}
        AND base_type = 'home'
        AND storage_limit = 100
    SQL
  end
end
