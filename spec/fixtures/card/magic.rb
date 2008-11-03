class Card::Magic < Card
  def type_name
    "魔法カード"
  end

  def card_cost
    skill_cost
  end

  def cost_or_kind
    kind
  end
end
