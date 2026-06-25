module GameHelper
  def signed_bonus(value)
    format("%+d", value.to_i)
  end
end
