class AddFoodAttributesToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :food, :boolean, default: false, null: false
    add_column :items, :tastiness, :integer, default: 0, null: false
    add_column :items, :satiety_restore, :integer, default: 0, null: false
    add_column :items, :eat_effect_data, :text, default: "{}", null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE items
          SET food = TRUE,
              tastiness = 35,
              satiety_restore = 3,
              eat_effect_data = '{"hp":5}'
          WHERE name = '薬草'
        SQL
      end
    end
  end
end
