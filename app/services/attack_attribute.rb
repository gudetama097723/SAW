class AttackAttribute
  TYPES = {
    "slash" => { label: "斬撃", canonical: "斬撃" },
    "pierce" => { label: "刺突", canonical: "刺突" },
    "blow" => { label: "殴打", canonical: "打撃" },
    "strike" => { label: "殴打", canonical: "打撃" },
    "斬撃" => { label: "斬撃", canonical: "斬撃" },
    "刺突" => { label: "刺突", canonical: "刺突" },
    "殴打" => { label: "殴打", canonical: "打撃" },
    "打撃" => { label: "殴打", canonical: "打撃" }
  }.freeze

  NORMAL_ATTACKS = %w[斬撃 刺突 打撃].freeze

  def self.normalize(value)
    TYPES.fetch(value.to_s.strip, TYPES["slash"])[:canonical]
  end

  def self.label(value)
    TYPES.fetch(value.to_s.strip, TYPES[normalize(value)])[:label]
  end

  def self.normal_attack_options
    NORMAL_ATTACKS.map { |attribute| [attribute == "打撃" ? "殴打" : attribute, attribute] }
  end
end
