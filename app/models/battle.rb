class Battle < ApplicationRecord
  INITIATIVE_TYPES = %w[normal player_ambush enemy_ambush].freeze

  belongs_to :player
  belongs_to :mob
  has_many :battle_enemies, dependent: :destroy

  def alive_enemies
    battle_enemies.alive
  end

  def initiative_key
    INITIATIVE_TYPES.include?(initiative_type.to_s) ? initiative_type.to_s : "normal"
  end

  def player_ambush?
    initiative_key == "player_ambush"
  end

  def enemy_ambush?
    initiative_key == "enemy_ambush"
  end
end
