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
require 'reggraphpoint'
module Reg
  module Reg

    #turns a Reg that matches into a Reg that matches and
    #replaces. (creates a Reg::Transform)
    def >>(rep)
      Transform.new(self,rep)
    end
    
    def finally(&block)
      Finally.new(self,block)
    end
  end
  
  class Finally
    include Reg,Undoable,Composite
    
    def initialize(reg,block)
      @reg,@block=reg,block
      super
    end
    
    def mmatch(progress)
      progress.register_later progress &@block #shouldn't this be after mmatch?
      
      @reg.mmatch progress
    end
    
    #forward most other things to @reg (but what??)
  end


=begin contexts for a Reg::Transform
    an element of a Reg::Array, Reg::Subseq or Reg::Repeat (sequence)
    a key matcher in a Reg::Hash or similar
    a value matcher in Reg::Hash or similar
    a value matcher in Reg::Object
    directly in a top-level matcher

    but a Reg::Logical (Or,  for instance) could be in any of above, and a Transform could be within.
=end
  
  module TransformUndoable
    include Undoable
  end
  
  class Transform
    include Reg,TransformUndoable,Composite
    
    def initialize(reg,rep)
      Replace===rep or rep=Replace.make_replace( rep )
      @left,@right=reg,rep
      @reg,@rep=reg,rep
      super
    end

    attr_reader :left,:right
    attr_reader :reg,:rep

    alias from left
    alias to right

     
    def mmatch(progress)
      origpos=progress.get_index
      result=@reg.mmatch(progress) or return 
      MatchSet===result and return ReplaceMatchSet.new(self,progress,origpos,result)
      replace origpos,result.last,progress
      return result    
    end
    
    def replace(origpos,len,progress)
      Eventually===@rep and huh
      progress.register_replace(origpos,len, @rep) 
    end
  end
  
=begin  
  varieties of Reg::Replace: (replacement values)
  Reg::BackrefLike
  Reg::Bound ???
  Reg::RepProc ... not invented yet
  Reg::ItemThat... maybe not, but some sort of Deferred?
  Reg::Equals (or Literal, it's descendant)
  Reg::Fixed
  Reg::Subseq... interpolate items
  any other Object (as if wrapped in Reg::Fixed)
  (Reg::Array inserts an array at that point. Reg::Subseq 
   inlines its items at that point. when used this way, 
   they are not matching anything, nor are the contents necessarily matchers.
   they just serve as convenient container classes.)
  (to actually insert a Reg::Array or anything that's special at this point,
   wrap it in a Reg::Literal.)
  Array (as if Reg::Array?)
  Reg::Transform????
=end
  
  module Replace
    def self.evaluate(item,progress,gpoint) #at match time
      huh
      case item
      when BackrefLike; item.formula_value(nil,progress)
      when ItemThatLike; item.formula_value(gpoint.old_value,progress)
#      when Bound: huh
#      when Transform: huh????
      when ::Reg::Array 
        assert gpoint.is_a?( GraphPoint::Array)
        [item.regs]
      when ::Reg::Subseq
        assert gpoint.is_a?( GraphPoint::Array)
        item.regs
      when ::Array; huh 'like Reg::Array or Reg::Subseq?'
      when ::Reg::Wrapper; item.unwrap
      when Replace::Form; item.fill_out(progress,gpoint)
      else item #like it was wrapped in Reg::Fixed
      end
    end
  
    def self.make_replace item #at compile time
      case item
      when Deferred,Wrapper,BoundRef #do nothing
      when ::Reg::Subseq; huh
      when ::Reg::Reg; huh #error?
      else 
        needsinterp=false
        Ron::GraphWalk.graphwalk(item){|cntr,datum,idx,idxtype|
          case datum
          when Deferred,Wrapper
            break needsinterp=true
          end
        }
        needsinterp and item=Replace::Form.new(item)
      end
      item      
    end
  
    
    
    class Form #kinda like a lisp form... as far as i understand them anyway
      def initialize(repldata)
        @repldata=repldata
        cntrstack=[]
        @alwaysdupit=Set[]
        traverser=proc{|cntr,o,i,ty|
          
          cntrstack.push cntr     if cntr   
            case o
            when Deferred,Literal; @alwaysdupit|=cntrstack
            end
            GraphWalk.traverse(o,&traverser)
          cntrstack.pop
        }
        GraphWalk.traverse(repldata,&traverser)
      end
      
      def fill_out_simple(session,other)
        incomplete=false
        result=Ron::GraphWalk.graphcopy(@repldata) {|cntr,o,i,ty,useit|
          useit[0]=true
          @alwaysdupit.include?(o) ? o.dup : 
          newo=case o
#          when ItemThatLike,RegThatLike;
#            o.formula_value(other,session)
          when Deferred;           huh #if there's any Deferred items in @repldata, evaluate (#formula_value) them now
            o.formula_value(other,session)
          when Literal;  o.unwrap #literal items should be unwrapped
          when BoundRef; o.formula_value(other,session)
          else useit[0]=false
          end
          incomplete=true if Deferred===newo and not Literal===o
          newo
        }
        result=Form.new result if incomplete and !session["final"]
        return result
      end

      def fill_out(progress,gpoint)
        Ron::GraphWalk.graphcopy(@repldata) {|cntr,o,i,ty,useit|
          useit[0]=true
          @alwaysdupit.include?(o) ? o.dup : 
          case o
          when ItemThatLike,RegThatLike
            o.formula_value(gpoint.old_value,progress)
          when Deferred;           huh #if there's any Deferred items in @repldata, evaluate (#formula_value) them now
            o.formula_value(huh nil,progress)
          when Literal;  o.unwrap #literal items should be unwrapped
          else useit[0]=false
          end        
        }
        
      
        huh
      end
    
      warn "unfinished code..."
    end
  end
  
end
