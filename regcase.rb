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
  class Case
    include Reg
    include Composite
    def initialize(*args)
      if args.size==1 and Hash===args.first 
        scalars=[]; sets=[]
        matchers=[];
        
        args.first.each{|k,v|
           if Reg.interesting_matcher? k
            matchers<<k.reg**v
          elsif Set===k
            sets<<k.reg**v
          else
            scalars<<k.reg**v
          end        
        }
        args=scalars+sets+matchers
      end
      
      @others=None
      others_given=nil
      @pairlist=args.delete_if{|a|
          if !(Pair===a)
            warn "ignoring non-Reg::Pair in Reg::Case: #{a}"
            true
          elsif OB==a.left
            others_given and warn 'more than one default specified'
            others_given=true
            @others=a.right
          end  
      }
      super
      assert(!is_a? Multiple)
    end
  
    def ===(other)
      @pairlist.each{|pair|
        pair.left===other and pair.right===other || return
      } or @others===other
    end
  
    #hash-based optimization of scalars and sets is possible here
    
    def previous_matchers(val,*)
      val #by default, do nothing
    end
    
    def previous_matchers_ordered(val,index,other)
      val,index=*args
      (0..index).each{|i|
        pair=@pairlist[i]
        
        pair.left===other and pair.right===other || return
      }
      
    end
    
    def subregs
      result=@pairlist.inject([]){|a,pair| a+pair.to_a}
      result+=[OB,@others] if @others
      return result
    end
  
  end
  
  Rac=Case #tla of case
  assign_TLA :Rac=>:Case
end