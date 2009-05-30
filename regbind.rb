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
      Bound.new(name,self)
    end
    alias % bind
    
    def side_effect(&block); SideEffect.new(self,&block) end
    def undo(&block); Undo.new(self,&block) end

    def normalize_bind_name(name)
      case name    
      when Reg: name=name.inspect
      when Symbol:
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
      @name.inspect+"<<"+@reg.inspect
    end
  end

  #-------------------------------------
  class BoundRef
    include Formula
    def initialize(name)
      @name=name
    end
    attr :name

    def <<(other)
      ::Reg::Bound.new(name,other)
    end

    def formula_value(other,session)
      session[@name]
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
