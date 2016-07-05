=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2005, 2016  Caleb Clausen

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
=end
PcPirate=proc{ #arr

  alias_method :modulus__nopercent, :%
  define_method :% do |*other|
    unless other.empty?
      modulus__nopercent *other
    else
      Percent.new self
    end
  end
}

[Fixnum,Bignum,Float].each{|x| x.instance_eval &PcPirate }


class Percent
  attr :num
  def initialize(num)
    @num=num
  end
  
  
  def inspect
    @num.inspect+"%"
  end

  def coerce(other)
    [Quantity.new(other), self]
  end

  def -@
    Percent.new(-@num)
  end



  class Quantity
    attr :num

    def initialize(num)
      @num=num
    end
    
    def *(pc)
      @num*pc.num/100
    end
    
    def /(pc)
      @num/pc.num*100  
    end

    def +(pc)
      @num*(1 + pc.num/100.0)
    end
    
    def -(pc)
      self+ -pc
    end
  end
end

  class Numeric
    def with_delta(num)
      self-num..self+num
    end
  end
