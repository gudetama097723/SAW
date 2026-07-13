class BlacksmithProficiencyService
  GROWTH_SCALE = 300_000

  def self.award!(context, task_difficulty:, action:, completion_ratio: 1.0)
    return 0 unless context&.player?

    skill = BlacksmithService.blacksmith_skill_for(context.player)
    return 0 unless skill

    difference = task_difficulty.to_i - context.proficiency.to_i
    base = case difference
    when 150.. then 12
    when -150..149 then 8
    when -250..-151 then 3
    when -350..-251 then 1
    else 0
    end
    action_multiplier = { craft: 1.0, maintenance: 0.6, enhance: 0.8 }.fetch(action.to_sym)
    gained = (base * action_multiplier * completion_ratio.to_f.clamp(0.0, 1.0)).floor
    skill.gain_skill_exp!(gained, growth_scale: GROWTH_SCALE) if gained.positive?
    gained
  end
end
