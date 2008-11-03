class Card < ActiveRecord::Base
  def guess_class
    case no.to_i
    when   1...100 then Card::Unit
    when 200...300 then Card::Member
    when 700...800 then Card::Equip
    when 800...900 then Card::Magic
    else
      raise "Cannot guess for no=#{no}"
    end
  end
end
