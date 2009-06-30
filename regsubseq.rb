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
