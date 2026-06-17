class MobPart < ApplicationRecord
  belongs_to :mob

  def severable?
    break_effect.in?(%w[strength_down agility_down])
  end

  def break_message
    if severable?
      "#{name}を欠損させた！"
    elsif drop_item_name.present?
      "#{name}を破壊した！"
    else
      "#{name}を破壊した！"
    end
  end
end
