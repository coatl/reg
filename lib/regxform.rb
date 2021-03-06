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
require 'reg'
require 'regcompiler' #but then breaks it!

#use of this file breaks the compiler.
#only trees are supported. maybe dags if you're lucky.
#not full graphs.
#array matchers are not supported currently.

module Reg
  module Reg
    def xform!(datum,changed={})
      datum or fail
      Thread.current[:Reg_xform_session]=session={}
      changed.merge!(session) if self===datum
    ensure
      Thread.current[:Reg_xform_session]=nil
    end
  end

  class Bound
    def === other #this is a hack
      result= @reg===other
      session=Thread.current[:Reg_xform_session]
      if result and session and !session.has_key? @name
        session[@name]=other
      end
      return result
    end

    def formula_value other,session #another hack...
      result= @reg.formula_value other,session
      
      if session and !session.has_key? @name
        session[@name]=result
      end
      return result
    end
  end

  class BoundRef
    def inspect
      "~:#{name}"
    end
    def === other #this is a hack
      session=Thread.current[:Reg_xform_session]
      if session and session.has_key? @name
        session[@name]==other
      else raise NameNotBound #name not bound yet? that's an error
      end
    end

    def formula_value(other,session)
      warn "warning: BoundRef #{inspect} value missing" if !session.has_key?(name) and session["final"] 
      session.fetch(name,session["final"] ? nil : self)
    end
  end

  module Formula  #more hackery
    def % other
      if Symbol===other
        Reg::Bound.new(self,other)
      else
        super
      end
    end
  end

  module Composite
    def at_construct_time(*args)
      #do nothing, no infections at all are appropriate when using this file
    end
  end

  class NameNotBound<RuntimeError; end
  class ReplacingNilError<RuntimeError; end

  class Transform
    def inspect
      from.inspect+" >> "+to.inspect
    end
    def === other #this is a hack
      result= from===other
      session=Thread.current[:Reg_xform_session]
      if result and session
        raise ReplacingNilError,"replaces of nil or false are not allowed" unless other
        locals={:self=>other}
        if $&
          locals[:$&]=$&
          locals[:$`]=$`
          locals[:$']=$'
          $&.to_a.each_with_index{|br,i| locals[:"$#{i}"]=br }
        end
        session.each_pair{|name,val| locals[name]=val if ::Symbol===name } #hacky... names shouldn't need to be frozen here
        session[other.__id__]=WithBoundRefValues.new(to,locals)

=begin
          case to
          when Replace::Form; to.fill_out_simple(locals,other) #should handle Literals as well...
          when BoundRef; to.formula_value(other,locals) #must be eval'd early...?
          when Formula; WithBoundRefValues.new(to,locals)
          else to
          end
=end
      end
      return result
    end
  end

  class Replace::Form
    def formula_value other,session
      fill_out_simple session,other
    end
  end
 
  class And
    def === other  #hack around bugs in AndMachine
      @regs.each{|reg| return unless reg===other }
      return other||true
    end
    def multiple_infection(*args) end #hacky, never do anything for Reg::And
  end

  class Or
    def multiple_infection(*args) end #hacky, never do anything for Reg::Or
  end
  class Hash
    def multiple_infection(*args) end #hacky, never do anything for Reg::Hash
  end
  class Object
    def multiple_infection(*args) end #hacky, never do anything for Reg::Object
  end
  class Trace
    def multiple_infection(*args) end #hacky, never do anything for Reg::Trace
  end
  class BP
    def multiple_infection(*args) end #hacky, never do anything for Reg::BreakPoint
  end

  class Finally
    def ===(other)
      result= @reg===other
      session=Thread.current[:Reg_xform_session]
      if result and session
        session["finally"]||=[]
        session["finally"]<<[@block,other]
      end
      result
    end
  end

  class<<Object
    alias new__without_nested_nil_replacer_fix new
    IMMEDIATES=[nil,false,true,0,:symbol,Class]
    def new *args
      hash= (::Hash===args.last ? args.pop : {})
      replacing_immediate,normal={},{}
      hash.each_pair{|keymtr,valmtr| 
        if ::Reg::Transform===valmtr and !IMMEDIATES.grep(valmtr).empty? and ::Symbol===keymtr
          transform=valmtr
          normal[keymtr]=transform.from
          replacing_immediate[keymtr]=transform.to
        else
          normal[keymtr]=valmtr
        end
      }
      args.push normal
      result=new__without_nested_nil_replacer_fix(*args)
      unless replacing_immediate.empty?
        result=result.finally{|x,session|
          replacing_immediate.each_pair{|key,to|
            x.send "#{key}=",to.formula_value(x.send(key),session)
          }
        }
      end
      return result
    end
  end
end

tests=proc{
  require 'test/unit'
  class XformTests<Test::Unit::TestCase
    alias assert_op assert_operator
    def test_and_with_bound_and_replace
      assert_op String>>"bop", :===, "sdfsdf"
      assert String>>"bop" === "sdfsdf"
      assert_op +{ :body=>String >> 'bop' }, :===, {:body => "23423"}
      assert_op (/sdfgdf/ | Hash )%:top & +{ :body=>String >> 'bop' }, :===, {:body => "23423"}
      assert_op( (((/7869/ | Hash )%:top) & +{ :body=>String >> 'sdf' }) | Symbol, :===, Hash[:body, "4564563"] )
      assert_op( ((((/7869/ | Hash )%:top) & +{ :body=>String >> 'sdf' }) | Symbol).trace, :===, Hash[:body, "4564563"] )
    end
  end
}
tests[] if __FILE__==$0
