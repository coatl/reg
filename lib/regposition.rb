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
require 'set'
#require 'reg'
module Reg
  class Position
    include ::Reg::Reg
    
    class<<self
      alias new__no_negatives new
      def new(*nums)
#        Enumerable===nums or nums=[nums]
        #all nums should have the same sign, so
        #1st num determines if all nums are 'from end'
        return FromEnd.new(*nums) if negative?(nums.first)
        new__no_negatives nums
      end
      alias [] new
    
      def negative? x
        1.0/x < 0 rescue return
      end
    end
    
    def initialize(*nums)
      @positions=Set[*nums]
    end
    
    def mmatch(pr)
      [true,0] if @positions===adjust_position(pr.cursor,pr.cursor.pos)
    end

    def itemrange
      0..0
    end
    
    def inspect
      "Reg::Position[#{@positions.inspect[8..-3]}]"
    end

  private
    def adjust_position(cu,pos)
      pos
    end
  


    class FromEnd < Position
      class<<self
        alias new new__no_negatives
        alias [] new
      end
      
      def inspect
        super.sub("ion","ion::FromEnd")
      end
    private
      def adjust_position(cu,pos)
        pos-cu.size
      end
    end
  end
end
