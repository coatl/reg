require 'warning'
require 'roggraphedge'



#to_rog

class Object
  #forward decls
  def to_rog; end
  def to_rog_list(x=nil); end
end

module Rog
  class NotSerializeableError<RuntimeError; end
  class NotYetSerializeableError<NotSerializeableError; end
  class NotYetMaybeNeverSerializeableError<NotSerializeableError; end
  
  class Session
    def initialize
      @objects_seen={} #hash of object id to reference to string in output
      @objects_in_progress=[]
      #@output=[] #array of strings of data to be output
    end    
    attr_reader :objects_in_progress, :objects_seen
  end  
  IGNORED_INSTANCE_VARIABLES=Hash.new{[]}
  DefaultMarker={}.freeze

  @@local_names_generated=0
  def Rog.gen_local_name
    "v#{@@local_names_generated+=1}_"
  end  
  
  CaptureCtx=[]
=begin  
  def self.recurse_safe_objects_equal?(o1,o2,session={})
    pair=[o1.__id__,o2.__id__]
    return true if session[pair]
    session[pair]=1
  
    o1.class==o2.class and
      case o1
      when Array: 
        o1.size==o2.size and
        o1.each_with_index{|i1,idx|
          recurse_safe_objects_equal?(i1,o2[idx],session) or return
        }
      
      when Hash:
        #oops, this depends on #== and #hash working right for recursive structures, which they don't.
        o1.size==o2.size or return      
        recurse_safe_objects_equal? o1.default,o2.default,session or return
        o1.each_with_index{|(idx,i1),bogus|
          return unless (o2.key? idx and recurse_safe_objects_equal? i1, o2[idx],session)
        }

      when Range:
        o1.exclude_end?()==o2.exclude_end?() and
        recurse_safe_objects_equal? o1.begin, o2.begin,session and 
        recurse_safe_objects_equal? o1.end, o2.end,session 

      when Struct:
        (mems=o1.members).size==o2.members.size and 
        mems.each{|i|
          recurse_safe_objects_equal? o1[i], (o2[i] rescue return),session or return
        }
      when Binding:
        recurse_safe_objects_equal? o1.to_h, o2.to_h, session
      when Proc,Integer,Float,String:
        o1==o2
      when Thread,ThreadGroup,Process,IO,Symbol,
           Continuation,Class,Module:
             return o1.equal?(o2)
      when Exception:
        o1.message==o2.message
      when MatchData: 
        o1.to_a==o2.to_a
      when Time:
        o1.eql? o2
      else true
      end and
      (iv1=o1.instance_variables).size==o2.instance_variables.size and
      iv1.each{|name| 
        recurse_safe_objects_equal? \
          o1.instance_variable_get(name), 
          (o2.instance_variable_get(name) rescue return),session or return
      } 
  end
=end
end

SR=Rog::DefaultMarker
#Recursive([SR]) #recursive array
#Recursive({SR=>SR}) #doubly recursive hash
#Recursive(Set[SR]) #recursive Set

module Recursive; end
SelfReferencing=Recursive        #old name alias
SelfReferential=SelfReferencing  #old name alias

def Recursive *args #marker='foo',data
  marker,data=*case args.size
  when 2: args
  when 1: [::Rog::DefaultMarker,args.last]
  else raise ArgumentError
  end

    ::Rog::GraphWalk.graphwalk(data){|cntr,o,i,ty|
      if o.equal? marker 
        ty.new(cntr,i,1){data}.replace
        data.extend Recursive
      end
    }  
    data
end
def SelfReferencing #old name alias
  Recursive(v=Object.new, yield(v))
end
alias SelfReferential SelfReferencing  #old name alias

class Object
  def with_ivars(hash)
    hash.each_pair{|k,v|
      instance_variable_set(k,v)
    }
    self
  end
end

[Fixnum,NilClass,FalseClass,TrueClass,Symbol].each{|k| 
  k.class_eval{ alias to_rog inspect; undef to_rog_list }
}
[Bignum,Float,].each{|k| 
  k.class_eval{ def to_rog_list(session) [inspect] end }
}

class String
    def to_rog_list session
      
      [ "'", gsub(/['\\]/){ '\\\\'+$&}, "'" ]
    end
end

class Regexp
    def to_rog_list session
      
      [ inspect ]
    end
end

class Array
  def to_rog_list session
    ["["] + 
     map{|i| 
          i.to_rog_list2(session)<<', ' 
        }.flatten<<
    "]"
  end
end

class Hash
  def to_rog_list session
    ["{"]+map{|k,v| 
      Array(k.to_rog_list2(session)).push "=>",
          v.to_rog_list2(session)<<', ' 
    }.flatten<<"}"
  end
end

class Object
  undef to_rog, to_rog_list #avoid warnings
  def to_rog
    warning "additional modules not handled"
      warning "prettified output not supported"
    
    to_rog_list2.to_s
  end
  
  def to_rog_list session
    self.class.name or raise NotSerializableError
    [self.class.name,"-{",
      *instance_variables.map{|ivar| 
        [ivar.to_rog,"=>",
          instance_variable_get(ivar).to_rog_list2(session),', ']
      }.flatten<<
    "}#end object literal"]
    #end
  end
  
  def to_rog_list2(session=Rog::Session.new)
    respond_to? :to_rog_list or return [to_rog]
    if pair=(session.objects_in_progress.assoc __id__)
      str=pair[1]
      if str[/^Recursive\(/]
        result=pair.last #put var name already generated into result
      else
        pair.push result=Rog.gen_local_name
        str[0,0]="Recursive(#{result}={}, "
      end
      result=[result]
    elsif pair=session.objects_seen[ __id__ ]
      str=pair.first
      if str[/^[a-z_0-9]+=[^=]/i] 
        result=pair.last #put var name already generated into result
      else
        pair.push result=Rog.gen_local_name
        str[0,0]=result+"="
      end
      result=[result]
    else
      str=''
      session.objects_in_progress.push [__id__,str]
      result=to_rog_list(session).unshift str
      if result.last=="}#end object literal" 
        result.last.replace "}"
      else
        #append instance_eval
        ivars=instance_variables-::Rog::IGNORED_INSTANCE_VARIABLES[self.class]
        ivars.empty? or result.push ".with_ivars(", *ivars.map{|iv| 
          [":",iv.to_s,"=>",instance_variable_get(iv).to_rog_list2(session),', ']
        }.flatten[0...-1]<<")"
      end
      result.push ")" if str[/^Recursive\(/]
      session.objects_seen[__id__]=[session.objects_in_progress.pop[1]]
      result
    end
    result
  end
end

class Struct
  def to_rog_list  session
    self.class.name or raise NotSerializableError
    result=[self.class.name,"-{"]+
      members.map{|memb| 
        [memb.to_rog_list2(session) , "=>" , self[memb] , ', ']
      }.flatten<<
    "}"
    result=["(",result,")"].flatten unless instance_variables.empty?
    result
  end
end

sets=[:Set,:SortedSet,:WeakRefSet]
eval sets.map{|k| <<END }.to_s 
class #{k} #{'< Set' if k==:SortedSet}
  def to_rog_list session
    ['#{k}[']+map{|i| i.to_rog_list2(session)<<', ' }.flatten<<"]"
  end
end
END
Rog::IGNORED_INSTANCE_VARIABLES[Set]=%w[@hash]
Rog::IGNORED_INSTANCE_VARIABLES[SortedSet]=%w[@hash @keys]
Rog::IGNORED_INSTANCE_VARIABLES[WeakRefSet]=%w[@ids]

class Range
  def to_rog_list session
#    result=
           ["(",*first.to_rog_list2(session).
                  push( "..#{'.' if exclude_end?}" )+
                  last.to_rog_list2(session)<<
            ")"
           ]
#    result.flatten!
#    result
  end
end


class Module
  def to_rog
    name.empty? and raise ::Rog::NotSerializeableError
    name
  end
  undef to_rog_list
end

class Class
  def to_rog
    name.empty? and raise ::Rog::NotSerializeableError
    name
  end
  undef to_rog_list if methods.include? "to_rog_list"
end

class Binding
  def to_h
    l=Kernel::eval "local_variables", self
    l<<"self"
    h={}
    l.each{|i| h[i.to_sym]=Kernel::eval i, self }
    h[:yield]=Kernel::eval "block_given? and proc{|*a| #,&b\n yield(*a) #,&b\n}", self
    h
  end
  
  def self.- h
    h=h.dup
    the_self=h.delete :self
    the_block=(h.delete :yield) || nil
    keys=h.keys
    keys.empty? or
    code=keys.map{|k| 
      k.to_s
    }.join(',')+'=*::Rog::CaptureCtx.last'
    mname="Rog__capture_binding#{Thread.current.object_id}" #unlikely method name
    newmname=result=nil

    eval "
          Thread.critical=true
           newmname=class<<the_self;
             mname=oldmname='#{mname}'
             im=instance_methods(false)
             mname+='-' while im.include? mname
             alias_method mname, oldmname
             def #{mname}
               #{code}
               binding
             end
             mname
           end
         " 
          ::Rog::CaptureCtx.push h.values
          result=the_self.send mname, &the_block
          ::Rog::CaptureCtx.pop
          class<<the_self;
             self
          end.send(*if newmname==mname
           [:remove_method, mname]
          else
           [:alias_method, mname, oldmname]
          end)
          Thread.critical=false
          result
  end
  
  def to_rog_list session
    result=to_h.to_rog_list2(session).unshift("Binding-")
    result=["(",result,")"].flatten unless instance_variables.empty?
    result
  end
end





#I might be able to implement these eventually....
[
Proc,
Method,
UnboundMethod,
#Binding,  #??
].each{|k| 
  k.class_eval do
    def to_rog(x=nil); raise Rog::NotYetSerializeableError end
    alias to_rog_list to_rog
  end
}

#what about unnamed class and module?


#not sure about these:
[
Continuation,
:Thread,
:ThreadGroup,

:Mutex, #??
#and other interthead communication mechanisms, like
:Queue,
:SizedQueue,
:RingBuffer,
:ConditionVariable,
:Semaphore,
:CountingSemaphore,
:Multiwait,
].each{|sym|
  k=(Object.const_get(sym) rescue nil) and 
  k.class_eval do
    def to_rog(x=nil); raise Rog:: NotYetMaybeNeverSerializeableError end
    alias to_rog_list to_rog
  end
}


#not a chance in hell:
[
File,
IO,
Dir,
Process,



].each{|k| 
  k.class_eval do
    def to_rog(x=nil); raise Rog::NotSerializeableError end
    alias to_rog_list to_rog
  end
}

=begin Kernel#self_referencing test case
exp=Reg::const  # or Reg::var
stmt=Reg::const  # or Reg::var

exp=exp.set! -[exp, '+', exp]|-['(', stmt, ')']|Integer
stmt=stmt.set! (-[stmt, ';', stmt]|-[exp, "\n"])-1
    --  or  --
stmt=Recursive(stmt={}, 
  (-[stmt, ';', stmt]|
  -[exp=Recursive(exp={}, 
    -[exp, '+', exp]|
    -['(', stmt, ')']|
    Integer
   ), "\n"])-1
)
=end

#Class#-
class Class
  #construct an instance of a class from the data in hash
  def - hash
    name.empty? and huh
    allocate.instance_eval{
      hash.each{|(k,v)| instance_variable_set(k,v) }
      return self
    }
  end
end

#Struct#-
class<<Struct
  alias new__no_minus_op new
  def new *args
    result=new__no_minus_op(*args)
    class<<result
  def - hash
    name.empty? and huh
    result=allocate
    hash.each{|(k,v)| result[k]=v }
    result
  end
    end
    result
  end
end
