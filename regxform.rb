module Reg
  module Reg
    def xform!(datum,changed={})
      datum or fail
      Thread.current[:Reg_xform_session]=session={}
      self===datum or return
      changed.merge!(session){|key,old,new| fail }
      return datum
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
  end

  class BoundRef
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

  class NameNotBound<RuntimeError; end

  class Transform
    def === other #this is a hack
      result= from===other
      session=Thread.current[:Reg_xform_session]
      if result and session
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
          when Deferred,BoundRef; to.formula_value(other,locals)
          else to
          end
      end
      return result
    end
  end
end
