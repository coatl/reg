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
  module Reg
    def bind(name=self)
      name=name.name if BoundRef===name
      Bound.new(name,self)
    end
    alias % bind
    
    def side_effect(&block); SideEffect.new(self,&block) end
    def undo(&block); Undo.new(self,&block) end
    def trace(&block); Trace.new(self,&block) end

    def normalize_bind_name(name)
      case name    
      when Reg; name=name.inspect
      when Symbol
      else name=name.to_s.to_sym
      end
    end

  end
  
  #-------------------------------------
  class Bound
    include Reg,Undoable,Composite
    def initialize(name,reg)
      @name,@reg=(normalize_bind_name name),reg
      super
    end
  
    def mmatch(progress)
      progress.register_var(@name,progress.get_index)
      result=@reg.mmatch(progress)
      #the variable needs to be unbound if the match failed
      result or progress.delete_variable @name
      result
    end
  
  
    def mmatch_full(progress)
      huh "what if result is a matchset?"
      if result=@reg.mmatch(progress) 
        idx=progress.get_index
        range= if 1==result.last then idx else idx...idx+result.last end
        progress.register_var(@name,range)
      end
      return result
    end
    
    def inspect
      @reg.inspect+"%"+@name.inspect
    end
  end

  #-------------------------------------
  class BoundRef
    include Formula
    def initialize(name)
      @name=name
    end
    attr :name

    def formula_value(other,session)
      session[@name]
    end

    def == other
      BoundRef===other and other.name==name
    end

    def hash
      "BoundRef of ".<<(name.to_s).hash
    end

    def unparse o
      inspect
    end
  end


  #-------------------------------------
  class WithBoundRefValues
    include Formula
    def initialize(br,values)
      @br,@values=br,values
    end
    attr_reader :br,:values

    def formula_value(other,session)
      @br.formula_value(other,session.dup.merge!(@values))
    end

    def == other
      other.is_a? WithBoundRefValues and
        @br==other.br and @values==other.values
    end

    def hash
      #@value is a Hash, and Hash#hash doesn't work in ruby 1.8 (fixed in 1.9)
      #I thought I had a good implementation of Hash#hash somewhere....
      @br.hash^@value.huh_working_hash_hash
    end
  end

  #-------------------------------------
  class Trace
    include Reg,Composite
  
    def initialize(reg,&block)
      block||=proc{|reg,other,result|
        print "not " unless result
        print reg.inspect, " === ", other.inspect, "\n"
      } 
      @reg,@block=reg,block
      super
#      extend( HasCmatch===@reg ? HasCmatch : HasBmatch )
    end
  
    def === other
      result= @reg===other
      @block.call @reg,other,result
      return result
    end

      def generate_bmatch
        "
        begin
          item=progress.cursor.readahead1
          result=@reg.bmatch progress
        ensure
          @block.call @reg,item,result
        end
        "
      end
      def generate_cmatch
        "
        begin
          success=nil
          item=progress.cursor.readahead1
          @reg.cmatch(progress){
            @block.call @reg,item,true
            success=true
            yield
          }
        ensure
          @block.call @reg,item,false unless success
        end
        "
      end
  end
  
  #-------------------------------------
  class SideEffect
    include Reg,Composite
  
    def initialize(reg,&block)
      @reg,@block=reg,block
      super
    end
  
    def mmatch(progress)
      huh "what if result is a matchset?"
      result=@reg.mmatch(progress) and 
        @block.call(progress)
      return result
    end
  end
  
  #------------------------------------
  class Undo
    include Reg,Undoable,Composite
  
    def initialize(reg,&block)
      @reg,@block=reg,block
      super
    end
  
    def mmatch(progress)
      huh "what if result is a matchset?"
      result=@reg.mmatch(progress) and 
        progress.register_undo(@block)
      return result
    end
  end
end
