class KeyItem < ApplicationRecord
  belongs_to :player

  CATEGORIES = {
    "story" => "ストーリー",
    "quest" => "クエスト",
    "npc" => "NPC関連",
    "map" => "地図・探索情報",
    "collection" => "コレクション",
    "system" => "システム"
  }.freeze

  validates :name, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES.keys }
  validates :unique_key, uniqueness: { scope: :player_id }, allow_nil: true

  before_validation :set_default_obtained_at, on: :create

  def category_label
    CATEGORIES.fetch(category, "その他")
  end

  def obtained_at_label
    return "不明" unless obtained_at

    obtained_at.strftime("%Y/%m/%d %H:%M")
  end

  private

  def set_default_obtained_at
    self.obtained_at ||= Time.current
  end
end
