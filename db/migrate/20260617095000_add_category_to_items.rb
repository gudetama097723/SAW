class AddCategoryToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :category, :string, default: "misc", null: false
    reversible do |dir|
      dir.up do
        execute "UPDATE items SET category = 'gathered' WHERE name = '薬草'"
        execute "UPDATE items SET category = 'healing' WHERE name = 'ポーション'"
        execute "UPDATE items SET category = 'drop' WHERE name IN ('スライムの核', 'ホーンラビットの角', '変異スライムの核')"
      end
    end
  end
end
