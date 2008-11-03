class Card::Member < Card
  def type_name
    "メンバーカード"
  end

  def card_cost
    skill_cost
  end

  def cost_or_kind
    kind
  end
end
