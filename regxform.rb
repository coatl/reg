require 'reg'
require 'regcompiler'
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
        session[other.__id__]=
          case to
          when Replace::Form; to.fill_out_simple(locals,other) #should handle Literals as well...
          when BoundRef; to.formula_value(other,locals) #must be eval'd early...?
          when Formula; WithBoundRefValues.new(to,locals)
          else to
          end
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
