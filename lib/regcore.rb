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

require 'trace_during.rb'




  Infinity= begin
    result= [ Float::MAX**Float::MAX, Float::MAX**2,  Float::MAX*2].max
    result.infinite? ? result : result=1.0/0
  rescue; Float::MAX  #maybe 1.0/0 doesn't work on some systems?
  end unless defined? Infinity
  
  #there's also this way: 999999999999999999999999999999999999999999999999e999999999999999999999999999999
  #but stuff like that sometimes returns zero, so it doesn't seem as reliable.
  #(plus it generates a warning)
            
  #Infinity>1_000_000 or raise 'Infinity is too small'
  Infinity.to_f.infinite? or raise "Infinity is merely very large, not infinite"
  
  NaN=[(Infinity*0 rescue nil), (0.0/0.0 rescue nil)].find{|x| x.nan?} or warn "oops, NaN is not set right (probably nil)..."

  #Infinity is the approved capitalization. 
  #INFINITY is the older form, still supported for now
  INFINITY= Infinity  unless defined? INFINITY
            
module Reg  #namespace
  class <<self
    #Reg::Array convenience constructor. see Array#+@ for details.
    def [](*args)
      ::Reg::Array.new(*args)
    end
  end

  #--------------------------
  #abstact ancestor of all reg classes
  module Reg  
  
  
  
    #=== must be defined in the includer for the appropriate types
    #and some others:
    #itemrange
    #scalar?, vector?, multiple?, variable?, multilength?, fixed?
    #starts_with
    #ends_with
    #breakdown
    #what else?
    
    #--------------------------
    def =~(other) 
      self===other
    rescue #this is rediculuous; === should never raise an exception
      false #I think the fix to Range#=== below elminates the need for this kind of thing
    end
    
=begin    
    #--------------------------
    #low-precedence method call
    def <=>(other)
      send other
    end
=end
    
    #--------------------------
    alias pristine_inspect inspect
    def pp_inspect 
      pp pristine_inspect
    end


    #--------------------------
    #makes a Reg object literal (aliased to +@ by default)
    def lit
      Literal.new(self)
    end
    def +@; lit end

    #--------------------------
    #makes a version of self suitable for use in Reg matching
    #expressions. in subclasses of Reg this just returns self.
    def reg; self end

    #--------------------------
    #returns a (vector) Reg that will match a list of self
    #separated by other. watch out if other and self might
    #match the same thing(s).
    def sep other; -[self,-[other,self]+0]; end
    #...or -[self.-, other.reg|Reg::Position[-0.0]].*

    #--------------------------
    #returns a (vector) Reg that will match a list of stuff
    #separated by self. somewhat analogous to Regexp#split,
    #but returns the separators as well.
    def splitter; OBS.l.sep self; end
    
    #split the input into records using self as a separator expression.
    #block, if given will be invoked with each record. with no block,
    #an array of records is returned.
    def split(input,&block)
      unless block
        result=[]
        block=proc{|x| result<<x}
      end
      
      huh #convert input to cursor if it isn't already
      
      while input.skip_until(self)
        block.call $`  #`
      end
      return result
    end

=begin
    #--------------------------
    #set a breakpoint when matches against a Reg
    #are made. of dubious value to those unfamiliar
    #with Reg::Array source code.
    def bp #:nodoc: all
      class <<self #:nodoc:
        alias_method :unbroken___eee, :===     #:nodoc:
        alias_method :unbroken___mmatch,
           method_defined?(:mmatch) ? :mmatch : :fail #:nodoc:
        def ===(other)  #:nodoc:
          (defined? DEBUGGER__ or defined? Debugger) and Process.kill("INT",0)
          unbroken___eee other
        rescue
          false
        end

        def mmatch(*xx)  #:nodoc:
          (defined? DEBUGGER__ or defined? Debugger) and Process.kill("INT",0)
          unbroken___mmatch(*xx)
        end
      end
      self
    end
=end    

    #--------------------------
    #makes matcher greedy. on by default
    def g; self end
    
    #--------------------------
    #makes matcher lazy.
    def l; abstract end
    

    #--------------------------
    #*,+,-  are defined in regarray.rb
    #~,&,|,^ are defined in reglogic.rb
    #** is in reghash.rb
    #bind,side_effect,undo in regbind.rb
    #>> and finally in regreplace.rb
    #la,lb in reglookab.rb
    #+[],-[],+{},-{},-:symbol in regsugar.rb

    #--------------------------
    #return a list of sub Regs of this Reg (if any)
    def subregs
      []
    end

    #--------------------------
    #a simple reg that always starts this reg
    def starts_with
      self
    end

    #--------------------------
    #a simple reg that always ends this reg
    def ends_with
      self
    end

    #--------------------------
    #is the parameter an interesting matcher?
    #interesting matchers have an implementation of === that's
    #different form their ==. unfortunately, that's not easy to 
    #test in ruby. 
    #this algorithm isn't perfect, but it's pretty good.
    #in other words, very rarely, the method will fail and LIE to you.
    #it should work >99%, of the time I think. 
    def Reg.interesting_matcher?(mat) #a hack
      case mat
        when Integer,Float,Symbol,true,false,nil,Method,UnboundMethod; false
        when ItemThatLike,BackrefLike,Module,Set,Regexp,Range,::Reg::Reg; true
        #when Symbol,Pathname; false
        else
          /^#<UnboundMethod: .*\(Kernel\)#===>$/===mat.method(:===).unbind.inspect and return false
          assert( /^#<UnboundMethod: .*\(?(#<)?[A-Z:][A-Za-z_:0-9]+\>?\)?#===>$/===mat.method(:===).unbind.inspect )
          
          #in case there's an object that redefined ===, then defined it back to
          #== later in the inheiritance chain
          #or, someone might write: def === other; self==other end
          #out of ignorance that it's unnecessary
          
          eee_call=nil
          result=!trace_during(proc do|event,*stuff| 
            if /call$/===event
              eee_call=stuff
              
                #attempt to remain debuggable while restoring the old trace func
              set_trace_func((defined? DEBUGGER__ and (DEBUGGER__.context.method:trace_func).to_proc))              
            end
          end){mat===mat rescue false}; line=__LINE__
          assert eee_call[0] == __FILE__
          assert eee_call[1] == line
          assert eee_call[2] == :===
          assert eee_call[3].class == Binding
          assert Module===eee_call[4].class
          return eee_call[4]!=Kernel && result
      end
    end
    
    #--------------------------
    def interesting_matcher?(mat=self)
      Reg.interesting_matcher? mat
    end

  

    #--------------------------
=begin seems risky... disabled til I know why i want it
    def coerce(other)
      if Reg===other
        [other,self]
      else
        [other.reg,self]
      end
    end
=end

    #--------------------------
    def mmatch(ary,idx)
      assert idx<=ary.size
      idx==ary.size and return nil
      (self===ary[idx] rescue false) and [[[ary[idx]]],1]
    end

    protected

      #--------------------------
          
=begin
        #eventually, this will be a list of all tla mappings
        #RegMethods=proc do
        module_function
#        class<<self
          @@TLAs={}
          define_method :assign_TLA do |*args|
            hash=args.pop   #extract hash from args
            noconst,*bogus=*args #peel noconst off front of args 
            hash.each{|k,v| 
              v=@@TLAs[k]= noconst ? [v,true] : v #fold noconst into v (longname) and store in @@TLAs
              TLA_aliases k,v  #always alias the TLA into ::Reg namespace
            }
          end
          
          
          alias_method :assign_TLAs, :assign_TLA

          define_method :TLA_aliases do |short,long_args,*rest| myself=rest.first||::Object
            long=nil
            if ::Array===long_args 
              long=long_args.shift
              noconst=long_args.shift  #unfold noconst from long if folded
            else
              long=long_args
            end
            myself.const_set(short,::Reg::const_get(long)) unless noconst #alias the constant name
            
            #long=(::Reg.const_get long)  #convert long from symbol to a module or class
            myself.instance_eval %{
              private
              def #{short}(*args) #{long}.new( *args) end    #forward short name to long
            }
          end
 #       end
 #       def self.included(mod)
         # (class<<mod;self;end).instance_eval( &RegMethods    )
 #       end
 
    TLA_pirate= proc {         @@TLAs.each{|k,v| Reg.TLA_aliases k,v,self}       }
=end    
    
      
  end
#  TLA_pirate= Reg::TLA_pirate
  #the tlas (and where they're found):
  
  #Rob,Rah,Rap (reghash.rb)
  #Reg,Res,  (regarray.rb)
  #Rac,      (regcase.rb)
  #Rip       (right here, regcore.rb)-----v
  
  #p :TLA_stuff_defined
  
  #forward decl
  module Composite; end
  module CausesBacktracking; end
  
  
  
  #--------------------------
  class Wrapper 
  
    include Reg
    def initialize(o=nil)
      @o=o
      #super
    end

    def lit; @o end
    alias unwrap lit

    def ===x; raise NoMethodError.new( "Reg::Wrapper is abstract") end
  
  end
  
  
  #--------------------------
  class Fixed < Wrapper #matches like a plain object, but responds to Reg#|, etc
  #but still behaves in a match just like the unadorned obj (uses wrapee's === to match)
    def inspect
      if Reg===@o
      "Reg::Fixed.new("+@o.inspect+")"
      else
      "(#{@o.inspect}).reg"
      end
    end
    
    def ===(other)
      @o===other
    rescue #shouldn't be needed
      false
    end
    
    def matches_class
      huh
    end
  end


  #--------------------------
  class Equals < Wrapper #like Reg::Fixed, but == instead of ===
    def ===(other)
      @o==other
    end
    
    def inspect; huh end

    def matches_class; @o.class end
  end

  #--------------------------
  class Literal < Equals #a literalized Reg
    #literal is really the same as const... the 2 classes should be merged
    def reg; @o end
    def lit; Literal.new self end
    def unlit; @o end
    
    def formula_value(*ctx)
      @o
    end

    def inspect; huh end
  end

  #--------------------------
  class ::Object
    #turns any object into a matcher which matches the same 
    #thing that the object matches, except it's also a Reg::Reg,
    #and thus respects reg's meanings of: +,*,>>,&,~, etc
    #the generic case creates a wrapper Reg around any object whose ===
    #forwards to the wrapped object's ===. the original object is
    #unchanged.
    def reg
      Fixed.new(self)
    end
    def to_reg; reg end

    # return a literal version of the object... one whose === has been
    # forced to be the same as ==, regardless of whether it's usually
    # a matcher or not.
    def lit
      self #implementation needs some more work...
    end
    
    #just like ===, but receiver and argument are switched.
    #for those situations where you just have to put the item
    #to match to the left, and the pattern on the right.
    def matches pattern
      pattern===self
    rescue #shouldn't be needed
      false
    end
  end

  #--------------------------
  String=::Regexp

  #--------------------------
  class Symbol
    include Reg

    def initialize(rex)
      @rex=rex
#      super
    end

    def matches_class; ::Symbol end

    def ===(other)
      ::Symbol===other and m=@rex.match(other.to_s) and m[0]
    end

    def inspect
      @rex.inspect+'.sym'
    end
  end

  #--------------------------
  #a dynamically created Reg
  def (::Reg).regproc klass=::Object,&block
    Interpret.new(&block)
  end

  class Interpret  #a Reg whose makeup isn't determined until matchtime.
    include Reg
    
    def initialize(&matchercode)
      @matchercode=matchercode
      super
    end

    def ===(other)
      mtr=@matchercode.call(Progress.new(self,::Sequence::SingleItem.new(other)))
      mtr===other rescue false
         #eventually pass more params to call?
    end
    
    def mmatch(progress)
      @matchercode.call(progress).mmatch(progress)
    end
    
    #assign_TLA true, :Rip=>:Interpret
  end


  
end


#workaround potential error in class Range. 
#ruby 1.9 appearently fixes this
begin
  ("a"..."b")===4
rescue Exception
  class Range
    #dammit, === should never raise an exception
    unsafe_eee = instance_method :===
    define_method(:===) {|other|
      unsafe_eee.bind(self)[other] rescue false
    }
  end
end
