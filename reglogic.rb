=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2005  Caleb Clausen

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

require 'warning'

module Reg

  #--------------------------
  module Reg

    #logical negation - returns a new reg that matches everything
    #that the receiver doesn't.
    def ~
      Not.new(self)
    end
    alias not ~

    #create a Reg matching either self or other (or both).
    #(creates a Reg::Or.)
    #Reg#|'s may be chained; the result is a single large
    #Reg::Or containing all the subexpressions directly,
    #rather than a linked list of Reg::Or's.
    #
    #if any subRegs of | are vector Regs, the larger | Reg
    #is considered a vector as well. eats as much
    #input as the subexpression which matched. unlike other
    #vector Reg expressions, | is not greedy; instead, the
    #first alternative which matches is accepted. (subject
    #to later backtracking, of course.)
    def |(other)
      Or.new(self,other)
    end

    #create a Reg matching self and other. (creates a Reg::And).
    #Reg#&'s may be chained; the result is a single large
    #Reg::And containing all the subexpressions directly,
    #rather than a linked list of Reg::And's.
    #
    #if any subRegs of & are vector Regs, the larger & Reg
    #is considered a vector as well. eats as much
    #input as the longest subexpression.
    def &(other)
      And.new(self,other)
    end

    #create a Reg matching either self or other, but not both.
    #(creates a Reg::Xor).
    #Reg#^'s may be chained; the result is a single large
    #Reg::Xor containing all the subexpressions directly,
    #rather than a linked list of Reg::Xor's. (believe it or not,
    #this has the same semantics.) in an xor chain created this
    #way, only one of the several alternatives may match. if
    #2 or more alternatives both match, the larger xor
    #expression will fail.
    #
    #if any subRegs of ^ are vector Regs, the larger ^ Reg
    #is considered a vector as well. eats as much input as
    #the (only) subReg which matches.
    def ^(other)
      Xor.new(self,other)
    end  
  
  end


  #--------------------------
  class Not
    include Reg,Composite
    def initialize(reg)
      @reg=Deferred.defang! reg
      super
    end
    def ===(obj)
      !(@reg===obj)
    end
    def ~
      @reg
    end
    

    #deMorgan's methods...
    def &(reg)
      if Not===reg
        ~( ~self | ~reg )
      else
        super reg
      end
    end
    def |(reg)
      if Not===reg
        ~( ~self & ~reg )
      else
        super reg
      end
    end
    def ^(reg)
      if Not===reg
        ~self ^ ~reg
      else
        super reg
      end
    end
    #a|b|!a|!b|!a^!b|a^b
    #0|0|1 |1 |0    |0
    #0|1|1 |0 |1    |1
    #1|0|0 |1 |1    |1
    #1|1|1 |1 |0    |0

    #mmatch_full implementation needed

    def inspect
      "~("+@reg.inspect+")"
    end

    def subregs; [@reg] end
  end
  
  #--------------------------
  #only subclasses should be created
  class Logical
    include Reg,Composite
    attr :regs
    class<<self
    def new(*regs)
      warning "optimization of Logicals over a single sub-expression disabled"
      #regs.size==1 and return regs.first
      regs=regs.map{|r| Deferred.defang! r }
      super
    end
    alias [] new
    end
    def initialize(*regs)
      @regs=regs
      (@regs.size-1).downto(0){|i|
        @regs[i,1]=*@regs[i].subregs if self.class==@regs[i].class
      }

      super
    end
    def subregs; @regs.dup end
    
    
    def op(reg)
      newregs=@regs + ((self.class===reg )? reg.subregs : [reg])
      self.class.new(*newregs)
    end

    def mmatch(progress)
      progress.cursor.eof? and return
      other=progress.cursor.readahead1
      self.eee other and [true,1]
    end
    
    def max_matches; @regs.size end

    def self.specialize_with_operator oper
      %{
        alias_method :#{oper}, :op
        def inspect
          @regs.size==0 and return "::#{name}[]"
          @regs.size==1 and return "::#{name}[\#{@regs.first.inspect}]"
          @regs.collect{|r| r.inspect}.join' #{oper} '
        end
      }
    end  
  end

  #--------------------------
  class Or < Logical
    def ===(obj)
      @regs.each {|reg| reg===obj  and return obj || true }
      return false
    end
    alias eee ===
    eval specialize_with_operator(:|)
  end
  #--------------------------
  class And < Logical
    def ===(obj)
      @regs.each {|reg| reg===obj  or return false }
      return obj || true
    end
    alias eee ===
    eval specialize_with_operator(:&)
  end
  #--------------------------
  class Xor < Logical
    def ===(obj)
      @regs.find_all {|reg| reg===obj }.size==1 or return
      return obj || true
    end
    alias eee ===
    eval specialize_with_operator(:^) 
  end
  
end
