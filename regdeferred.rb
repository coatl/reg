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

#----------------------------------
module Kernel
  def formula_value(*ctx) #hopefully, no-one else will ever use this same name....
    self
  end
end

module Reg
  #----------------------------------
  #BlankSlate,Formula,Deferred,and Const are courtesy of Jim Weirich.
  #Slightly modified by me.
  #see http://onestepback.org/index.cgi/Tech/Ruby/SlowingDownCalculations.rdoc
  
  
  
  
  #----------------------------------
  module BlankSlate
    module ClassMethods
      def restore(*names)
        names.each{|name| alias_method name, "##{name}"}    
      end
      def hide(*names)
        names.each do|name| 
          undef_method name  if instance_methods.include?(name.to_s)
        end
      end
    end
  
    def BlankSlate.included(othermod)
      othermod.instance_eval {
        ms=instance_methods#+private_instance_methods
        ms.each { |m| 
          next if m=="initialize"
          alias_method "##{m}", m #archive m
          undef_method m unless m =~ /^__/ || m=='instance_eval'
        }
        extend BlankSlate::ClassMethods      
      }
    end
    def BlankSlate.extended(other)
      class <<other
        ms=instance_methods#+private_instance_methods
        ms.each { |m| 
          next if m=="initialize"
          alias_method "##{m}", m #archive m
          undef_method m unless m =~ /^__/ || m=='instance_eval'
        }
        extend BlankSlate::ClassMethods      
      end
    end
  end
  
  #----------------------------------
  module Formula 
    def method_missing(sym, *args, &block)
      Deferred.new(self, mixmod, sym, args, block)
    end
    alias deferred method_missing

    def mixmod; nil end #default is not contagious
    
    def coerce(other)
      [Const.new(other), self]
    end
    
    def formula_value(*ctx)
      fail "Subclass Responsibility"
    end
  end

  #----------------------------------
  class Deferred 
    include BlankSlate
    restore :inspect,:extend
    restore :respond_to?
#    restore :respond_to?
    include Formula
    attr_reader :operation, :args, :target, :block
        
    def initialize(target, mod, operation, args, block)
      @target = target
      @operation = operation
      @args = args
      @block = block
      mod ||= args.grep(Formula).first.class.ancestors.grep(DeferredQuery.reg|BackrefLike).first
      mod and extend mod
    end
    
    def formula_value(*ctx)
      @target.formula_value(*ctx).send(@operation, *eval_args(*ctx), &@block)
    end
    
    private
    
    def eval_args(*ctx)
      @args.collect { |a| a.formula_value(*ctx) }
    end

    class <<self
      alias new__no_const new
      def new(*args)
        if args.size==1
          Const.new( *args)
        else
          new__no_const( *args)
        end
      end

      def defang!(x)
        class<<x
          instance_methods.+(private_instance_methods).grep(/\A\#/).each{|n| alias_method n[1..-1],n }
          undef method_missing
        end if Deferred===x
        return x
      end
    end

    class Const 
      include BlankSlate
      restore :inspect,:extend
      include Formula
    
      def initialize(value)
        @formula_value = value
      end
      def formula_value(*ctx) @formula_value end
      
      class<<self
        alias [] new
      end
    end
    
  end



end
