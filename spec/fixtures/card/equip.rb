class Card::Equip < Card
  def type_name
    "装備カード"
  end

  def card_cost
    skill_cost
  end

  def cost_or_kind
    kind
  end
end
