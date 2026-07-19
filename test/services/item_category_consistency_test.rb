require "test_helper"

class ItemCategoryConsistencyTest < ActiveSupport::TestCase
  test "every item name resolves to a single category across all seed sources" do
    conflicts = categories_by_item_name.each_with_object({}) do |(name, categories), result|
      canonical = categories.uniq.map { |category| Item.canonical_category(name, category) }.uniq
      result[name] = categories.uniq if canonical.size > 1
    end

    assert_empty conflicts, <<~MSG
      同じ品名が入手経路によって異なるcategoryで携行録に入るため、所持品一覧で同じアイテムが分裂表示される。
      db/seeds配下のcategory列を統一するか、Item::CATEGORY_OVERRIDESに追記して解消すること: #{conflicts.inspect}
    MSG
  end

  private

  def categories_by_item_name
    result = Hash.new { |hash, key| hash[key] = [] }

    SimpleCsv.foreach(Rails.root.join("db/seeds/item_shop_items.csv")) do |row|
      result[row["item_name"]] << row["category"].presence
    end

    SimpleCsv.foreach(Rails.root.join("db/seeds/gathering_items.csv")) do |row|
      result[row["item_name"]] << (row["category"].presence || "gathered")
    end

    SimpleCsv.foreach(Rails.root.join("db/seeds/mob_drops.csv")) do |row|
      result[row["item_name"]] << (row["category"].presence || "drop")
    end

    SimpleCsv.foreach(Rails.root.join("db/seeds/mob_parts.csv")) do |row|
      next if row["drop_item_name"].blank?

      result[row["drop_item_name"]] << "drop"
    end

    %w[db/seeds/boss_mobs.csv db/seeds/treasure_chests.csv db/seeds/npc_quests.csv].each do |relative_path|
      collect_reward_item_categories(relative_path, result)
    end

    result
  end

  def collect_reward_item_categories(relative_path, result)
    SimpleCsv.foreach(Rails.root.join(relative_path)) do |row|
      raw = row["reward_data"]
      next if raw.blank?

      data = JSON.parse(raw)
      Array(data["items"]).each do |item|
        next if item["category"] == "key_item"

        result[item["name"]] << (item["category"].presence || "drop")
      end
    end
  end
end
