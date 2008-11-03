class Card::Unit < Card
  def type_name
    "ユニットカード"
  end

  def card_cost
    cost
  end

  def cost_or_kind
    cost
  end
end
