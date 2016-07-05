=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2016  Caleb Clausen

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
require 'regarray'
module Reg

  #--------------------------
  class Subseq < ::Reg::Array
    include Multiple,Composite

    def max_matches; @regs.size end

    def initialize(*regs)
      regs.each{|reg| 
        class<<self
          undef mmatch
          def mmatch(*xx) mmatch_full(*xx) end
        end if Multiple===reg
      
        if reg.equal? self or (Variable===reg and reg.lit.equal? self)
          raise RegParseError, "subsequence cannot directly contain itself"
        end
      }

      super
    end

    def inspect
      super.sub( /^\+/,'-')
    end
    
    def enough_matches? matchcnt,eof
      matchcnt==@regs.size
    end
    
    alias itemrange subitemrange
    
    def -@ #subsequence inclusion... that's what we are, do nothing
      self
    end
    
    def +@ #cvt to Reg::Array
      Array.new(*@regs)
    end

  private

#p ancestors
#tla of +[], regproc{}
#::Reg::Array.assign_TLA true, :Reg=>:Array
#::Reg::Array.assign_TLA :Res=>:Subseq
#no need to alias the constant name 'Reg', too.
#ruby does it for us.
  end


end
