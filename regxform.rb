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
  end

  class NameNotBound<RuntimeError; end

  class Transform
    def === other #this is a hack
      result= @reg===other
      session=Thread.current[:Reg_xform_session]
      if result and session
        begin
          oldme=session[:$&]
          session[:$&]=self
          session[other.__id__]=
            case @rep
            when Replace::Form; @rep.fill_out_simple(session,other) #should handle Literals as well...
            when Deferred; @rep #can't replace this yet either... #was: @rep.formula_value(session,other)
            when BoundRef; @rep #can't replace it yet...
            else @rep
            end
        ensure
          session[:$&]=oldme
        end
      end
      return result
    end
  end
end
