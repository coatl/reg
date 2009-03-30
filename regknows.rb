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
module Reg
  class Knows
    include Reg
    attr :sym
    def initialize(sym) 
      @sym=sym 
      super
    end
  
    def === (obj)
      obj.respond_to? @sym
    end

    def [] *args
      Args.new(sym,*args)
    end

    def -@; self end

    def inspect
      "-:#{sym}"
    end
    
    #(also, the usual [] => new alias)
    class<< self
      alias[]new
    end

    class Args < Knows
      attr :argsreg
      
      def initialize(sym,*argsreg)
        super sym
        @argsreg=::Reg[*argsreg]
      end 
      
      def inspect
        ":#{sym}"+@argsreg.inspect[1..-1]
      end
      def ===(obj)
        super and huh "need some more help here"
      end
      def -@; self end
    end

  end
  
end
