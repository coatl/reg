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


#the names defined here are considered obsolete, and will not be supported
#anymore at some point in the future.
OBSOLETE_NAMES=["And", "Array","Equals", "Fixed", "Hash", "Literal", 
                "Multiple", "Not", "Object", "Or", "Repeat", 
                "String", "Subseq", "Symbol", "Xor"]
for name in OBSOLETE_NAMES do
     
     if Class===::Reg.const_get(name)
       eval <<-endeval
         class ::Reg#{name} < Reg::#{name} 
         
           def initialize(*args,&block)
             @@warned_already ||= !warn("Reg#{name} is obsolete; use Reg::#{name} instead")
             super
           end
         end
       endeval
      else
       eval <<-endeval
         module ::Reg#{name}; include Reg::#{name}
           def self.included(*args,&block)
             @@warned_already ||= !warn("Reg#{name} is obsolete; use Reg::#{name} instead")
             super
           end
         end
       endeval
        
      end
             
#  Object.const_set "Reg"+name, (Reg.const_get name)
end

#need a way to obsolete these...
Reg::Number=Range
Reg::Const=Reg::Deferred::Const

#--------------------------
#an executable Reg... a Proc that responds to ===
#obsolete: please use item_that instead.
def proceq(klass=Object,&block)
  @@proceqWarnedAlready ||= !warn( "proceq is obsolete; please use item_that instead")
  
  block.arity.abs==1 or raise ArgumentError.new( "must be 1 arg")
  class <<block
    include Reg::Reg
    def klass=(k) @@klass=k end
    alias === call
      #eventually pass (more) params to call
    def matches_class; @@klass end
    alias starts_with matches_class
    alias ends_with matches_class
  end
  block.klass=klass
  block
end
