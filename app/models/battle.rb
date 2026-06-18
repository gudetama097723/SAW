class Battle < ApplicationRecord
  belongs_to :player
  belongs_to :mob
  has_many :battle_enemies, dependent: :destroy

  def alive_enemies
    battle_enemies.alive
  end
end
