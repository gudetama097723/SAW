class BattleEnemy < ApplicationRecord
  belongs_to :battle
  belongs_to :mob

  scope :alive, -> { where("enemy_hp > 0").order(:position) }

  def alive?
    enemy_hp.to_i.positive?
  end
end
