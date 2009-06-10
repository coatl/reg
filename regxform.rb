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
        locals={:self=>other,:session => session}
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
end
