module AttributeOrder
  def self.included(othermod)
    othermod.extend case othermod
    when Class: ForClass
    when Module: ForModule
    else raise ArgumentError    
    end
  end
  
  class NoMoreSuperMethods<RuntimeError;  end
  
  def <=>(other)
    raise NoMoreSuperMethods
  end

  def ==(other)
    raise NoMoreSuperMethods
  end

  def eql?(other)
    raise NoMoreSuperMethods
  end

  def hash
    raise NoMoreSuperMethods
  end

module ForModule
 
 
  #writes a bunch of comparison/equality/construction methods for you,
  #all you have to do is define an order for the set of 'columns' or
  #attributes of the object for use in sorting. the attributes are 
  #allowed to be instance variables (with @) or properties (pairs of 
  #setter/getter methods)(without @). 
  #column_order and subclassing:
  #The columns that were declared in any a superclass (or module) 
  #are considered before the columns declared in this class. any
  #column from a superclass need not be repeated in this class.
  #the instance methods create by column_order are: 
  #  #==, #<=>, #eql?, and #hash.
  #none of these are written if a version already exists in this
  #subclass (not a module or superclass).
  
  #in addition, there are a couple of private utility methods
  #created: #attributes and #same_kind?.
  #also, a new constructor method, #make, is written in the class.
  
  def attribute_order(*ivars)
    #get trailing option list, if any (:column_order is only 1 known)
    @COLUMN_ORDER=ivars.pop[:column_order] if Hash===ivars.last
    
    #normalize/type check parameters
    @REG_ATTRIBUTE_ORDER= ivars.map{|ivar| 
      ivar=ivar.to_s
      raise ArgumentError unless #check for malformed names
        ivar[/^(@|self\.)?[A-Za-z_][A-Za-z0-9_]*$/]    
      
      #prepend 'self.' if ivar doesn't start with @ or 'self.'
      ivar[/^(@|self\.)/] or ivar[0,0]="self."
      ivar
    }
    
    #normalize column_order
    @COLUMN_ORDER and 
      @COLUMN_ORDER.map!{|ivar|
        ivar=case ivar
        when Integer: @REG_ATTRIBUTE_ORDER[ivar]
        when Symbol: ivar.to_s
        when String: ivar
        else fail ArgumentError
        end
        
        raise ArgumentError unless #check for malformed names
          ivar[/^(@|self\.)?[A-Za-z_][A-Za-z0-9_]*$/]    
        
        #prepend 'self.' if ivar doesn't start with @ or 'self.'
        ivar[/^(@|self\.)/] or ivar[0,0]="self."
        ivar
      }


    #column_order defaults to attribute order if not given
    cols=(anc.instance_variable_get :@COLUMN_ORDER or anc.instance_variable_get :@REG_ATTRIBUTE_ORDER or [])

    meths=instance_methods(false)

    module_eval <<-"END"
      private #utility methods
huh #name collision... these names need to be unique for each module/class
      def column_list  
        result=[#{cols.join ','}]
        result.pop while !result.empty? and result.last.nil?
        return result
      end
      def same_kind?(other)  huh #name collision... these names need to be unique for each module/class
        other.kind_of?(#{self}) || self.kind_of? other.class 
      end
    
      public
      #comparison method
      def <=>(other)
        (result=super rescue 0).nonzero? and return result
        same_kind?(other) and
          column_list<=>other.column_list
      end unless meths.include?("<=>")
      
      #equality/hash methods
      def ==(other)
        (super rescue true) and
        same_kind?(other) and
          column_list==other.column_list
      end unless meths.include?("==") 
      def eql?(other)
        (super rescue true) and
        same_kind?(other) and
          column_list.eql? other.column_list
      end unless meths.include?("eql?")
      def hash
        #{ops=[:^,:+,:^,:-];i=0
          column_list.inject("(super rescue 0).^ "){|s,o| 
            s+"#{o}.hash.#{ops[(i+=1)&3]} "
          }.sub(/\.[+^-] $/,'')
        }
      end unless meths.include?("hash")
    END
  end
end

module ForClass
  include ForModule
  def attribute_order(*stuff)
    super    
    attrs=ancestors.reverse.map{|anc| 
      anc.instance_variable_get :@REG_ATTRIBUTE_ORDER 
    }.compact
    
    class_eval <<-"END"
      #raw constructor
      def self.make(*args)
        allocate.instance_eval do
          named_args=if block_given?
            yield
          elsif args.size==#{attrs.size+1}
            args.pop
          end
          
          #array args
          #{attrs.join(",")+"=*args" unless attrs.empty?}
          
          #hash args
          named_args and
            eval named_args.to_a.map{|(name,val)|
              name=name.to_s
              if name[/^@[a-z_][a-z_0-9]*$/i]
                instance_variable_set(name,val)
                nil
              else
                #name is allowed to be a complex l-value expression: eg 'foo.bar' or '@baz[44]', etc
                ["self." unless /^@[^@]/===name,name,"=",val,"\n"]
              end
            }
        end
      end
    END
  end

end

end
