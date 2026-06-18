class Skill < ApplicationRecord
  belongs_to :player

  def gain_skill_exp!(amount, growth_scale:)
    before = proficiency.to_i
    self.skill_exp = skill_exp.to_i + amount.to_i
    self.proficiency = proficiency_from_exp(skill_exp, growth_scale)
    awarded_slot = false
    if before < 1000 && proficiency.to_i >= 1000 && !capstone_slot_awarded?
      self.capstone_slot_awarded = true
      player.increment!(:skill_slot_bonus)
      awarded_slot = true
    end
    save!
    awarded_slot
  end

  def proficiency_from_exp(exp, growth_scale)
    scale = [growth_scale.to_i, 1].max
    (1000 * (1 - Math.exp(-exp.to_i / scale.to_f))).floor.clamp(0, 1000)
  end
end
