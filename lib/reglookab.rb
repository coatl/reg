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
module Reg
  module Reg
    def la; LookAhead.new self end
    def lb; LookBack.new self end
  end


  class LookAhead
    include Reg
    include Multiple
    include Composite
    def initialize(reg)
      @reg=reg
      super
    end
    
    def mmatch(pr)
      @reg.mmatch(pr)
      return [true,0]
    end
    
    def mmatch_full
      huh
    end
    
    def itemrange; 0..0 end
    
    #most methods should be forwarded to @reg... tbd
  
  end
  
  
  class LookBack
    include Reg
    include Multiple
    include Composite
    
    
    def initialize(reg)
      
      r=reg.itemrange
      @r=r.last-r.first
      @reg=reg
      super
    end

    def itemrange; 0..0 end
    
    def mmatch(pr)
      warn "look at prev item, not next_"
      @reg.mmatch(pr)
      return [true,0]
    end
    
    def regs_ary(pos,r=@r)
      [ (OB-r).l, @reg, Position[pos] ] #require unimplemented lazy operator....
    end 

    def mmatch_full(pr)
      huh

      cu=pr.cursor
      ra=@reg.itemrange
      pos=cu.pos
      startpos=pos-ra.last
      pos>=ra.first or return
      r=if startpos<0 
        huh 'dunno what to do here'
        newlast=ra.last+startpos
        assert newlast>=ra.first #???
        startpos=0
        ra=ra.first..ra.last+startpos
        ra.last-ra.first
      else
        @r
      end
      reg= +regs_ary(pos,r)
      reg.mmatch pr.subprogress(cu.position(startpos))
      
      #original pr.cursor position should be unchanged
      assert pos==cu.pos
      
      #huh #result should be fixed up to remove evidence of 
      #the subsequence and all but it's middle element.
      return [true,0]
    end
 
    #most methods should be forwarded to @reg... tbd
  end
end
