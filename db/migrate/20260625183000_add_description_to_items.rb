class AddDescriptionToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :description, :text

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE items
          SET description = '見た目で明らかに毒があるとわかるキノコ。しかし匂いは意外と美味しそう。',
              food = TRUE,
              tastiness = 50,
              satiety_restore = 5,
              eat_effect_data = '{"statuses":{"poison":3}}'
          WHERE name = '毒キノコ'
        SQL
      end
    end
  end
end
