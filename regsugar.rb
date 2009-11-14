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

=begin
this file contains the various 'convenience constructors' which might pollute the
global namespace. it's optional, but highly recommended.

(note that reg.rb calls this, so requiring 'reg' gives you global sugar by default). 
=end

require 'set'



#tla sugar moved into the related files plus central stuff in regcore.rb
#(maybe the regcore stuff can move here?,,, but sugar is supposed to be optional...\

 
#need tlas for Reg::Knows, Reg::Symbol
 
    class Array
      def +@
        ::Reg::Array.new(*self)
      end
      def -@
        ::Reg::Subseq.new(*self)
      end
    end
    
    class Hash
      def +@
        ::Reg::Hash.new(self)
      end
      def -@
        ::Reg::Object.new(self)
      end
    end
    
    class Symbol
      def [](*args)
        huh #is the [] method even defined below?
        ::Reg::Knows.new(self)[*args]
      end
      
      def **(other)
        reg ** other
      end
      
      def -@
        #item_that.respond_to?(self).reg
        ::Reg::Knows.new(self)
      end
      
      def ~
        ::Reg::BoundRef.new(self)
      end
    end
    #i'd like to take String#-@ and #** too...
    
    
    class Regexp
      #just like the original version of ::Regexp#~ 
      #(except this takes an optional argument to 
      #compare against something else.)
      def cmp(other=$_); 
        self =~ other 
      end
            
      include ::Reg::Reg

      def matches_class; ::String end

      #creates a Regexp that works with symbols instead of strings
      def sym; ::Reg::Symbol.new(self) end

        #take over Regexp#~ to mean 'not' rather than 'compare to $_'
        #eval needed to avoid "class inside of def" syntax error
          #negates the sense of receiver regexp. returns something that matches everything
          #that the original didn't, (including all non-Strings!).
          undef ~
          alias ~ not
    end
    
    class Module
      include ::Reg::Reg
      #if the right side of oper & is also a Module...
      #could provide custom version of & here (and in Class)
      #to return not just a matcher, but a Module that combines
      #the two Modules... several complexities here.
    end
    
    class Range
      include ::Reg::Reg
      
      #could provide custom versions of &, |, maybe even ^ over Ranges
      def &(range)
        ::Range===range or return super
        l,rl=last,range.last
        l=l.pred if le=exclude_end?
        rl=rl.pred if re=range.exclude_end?
        l,le=*case l<=>rl
        when -1;  [l,le]
        when 0;   [l,le&&re]
        when 1;   [rl,re]
        else return super
        end
        return ::Range.new([first,range.first].max, l, le)
      rescue
        return super
      end

      def |(range)
        ::Range===range or return super
        l,rl=last,range.last
        l=l.pred if le=exclude_end?
        rl=rl.pred if re=range.exclude_end?
        if self===range.last 
          ::Range.new([first,range.first].min, self.last, le)
        elsif range===self.last
          ::Range.new([first,range.first].min, range.last, re)
        else
          super
        end
      rescue
        return super
      end

      def ^(range)
        ::Range===range or return super
        l,rl=last,range.last
        l=l.pred if le=exclude_end?
        rl=rl.pred if re=range.exclude_end?
        
        if first==range.first
          if last<range.last
            return super unless exclude_end?
            ::Range.new(last,range.last,range.exclude_end?)
          else
            return super unless range.exclude_end?
            ::Range.new(range.last,last,exclude_end?)
          end
        elsif last==range.last and exclude_end?()==range.exclude_end?
          if first<range.first
            first...range.first
          else
            range.first...first
          end
        else
          super
        end
      rescue
        return super
      end
    end
  
    class Set
      #&|^+- are already defined in Set... resolved by piracy below
      include ::Reg::Reg
      include ::Reg::Undoable  #just pretending here, to force Reg::Hash et al to use #mmatch_full instead of #===
      
      def mmatch(progress)
        other=progress.cursor.readahead1
        include? other and return [true,1]
      end
      #don't re-define ===; could break case statements that use Set in when expressions
      
      def >>(repl)
        class<<copy=dup
          def === other; include? other end
        end
        Reg::Transform.new(copy,repl)
      end
      
      #need an optimized ~ that returns a Set-like...
    end
    
    
    class Object
      %w[item_that item_is regproc BR BackRef].each{|name|
        eval "def #{name}(*a,&b) ::Reg.#{name}(*a,&b) end\n"      
      }
    end

=begin    
    def Object.+ list
      huh
    end

    def Array.+ list
      huh
    end
    
    def Array./ list
      huh
    end

    def String.+ list
      huh
    end

    def Hash.+ list
      huh
    end
=end
  
module ::Reg

  module Sugar    
    class << self
         
      @@oplookup =    {
        :"+"      => :"op_plus",
        :"-"      => :"op_minus",
        :"+@"     => :"op_plus_self",
        :"-@"     => :"op_minus_self",
        :"*"      => :"op_mul",
        :"**"     => :"op_pow",
        :"/"      => :"op_div",
        :"%"      => :"op_mod",
        :"<<"     => :"op_lshift",
        :">>"     => :"op_rshift",
        :"~"      => :"op_tilde",
        :"<=>"    => :"op_cmp",
        :"<"      => :"op_lt",
        :">"      => :"op_gt",
        :"=="     => :"op_equal",
        :"<="     => :"op_lt_eq",
        :">="     => :"op_gt_eq",
        :"==="    => :"op_case_eq",
        :"=~"     => :"op_apply",
        :"|"      => :"op_or",
        :"&"      => :"op_and",
        :"^"      => :"op_xor",
        :"[]"     => :"op_fetch",
        :"[]="    => :"op_store"
      }

      
      def alphabetic_name(meth)
        @@oplookup[meth] or case meth
          when /\?$/; :"op_#{meth[0...-1]}_p"
          when /!$/; :"op_#{meth[0...-1]}_bang"
          when /=$/; :"op_#{meth[0...-1]}_setter"
          when /^op_/; :"op_#{meth}"
          else meth
        end
      end
    
    
      #override klass's exisiting version of meth
      #in cases where the argument to meth has the
      #class of exception, delegate back to the existing
      #version of meth. otherwise, the Reg::Reg version
      #of meth is invoked.
      def pirate_school(klass,meth,exception)
      
        klass=klass.to_s; exception=exception.to_s
        /^::/===klass or klass="::#{klass}"
        /^::/===exception or exception="::#{exception}"
        eval %{
          class #{klass}
            setmeth=instance_method :#{meth}
            undef #{meth}
            regmeth= ::Reg::Reg.instance_method :#{meth}
            define_method :#{meth} do |other|
              #{exception}===other and return setmeth.bind(self).call(other)
              regmeth.bind(self).call(other)
            end
          end
        }
      end

        

    end
        
        #extend Set's version of certain operators to respect the
        #reg versions as well. (The type of the rhs determines which
        #version is used.)
        [:+, :-, :&, :|, :^ ].each {|opname| 
          pirate_school ::Set, opname, ::Enumerable
        } if ::Reg::Reg>::Set

  end
end


BR=::Reg::BR

Any=::Reg::Any if defined? ::Reg::Any
Many=::Reg::Many if defined? ::Reg::Many
None=::Reg::None if defined? ::Reg::None

#older names... to be obsoleted someday?
OB=::Reg::OB if defined? ::Reg::OB
OBS=::Reg::OBS if defined? ::Reg::OBS

Rah=::Reg::Hash
def Rah(hash={}) ::Reg::Hash.new(hash) end
alias matches_hash Rah

Res=::Reg::Subseq
def Res(*args) ::Reg::Subseq.new(args) end
alias matches_subsequence Res
alias matches_subseq matches_subsequence

Rob=::Reg::Object
def Rob(hash={}) ::Reg::Object.new(hash) end
alias matches_object Rob
alias matches_obj matches_object

def Reg(*args) ::Reg::Array.new(args) end
alias matches_array Reg
alias matches_arr matches_array

