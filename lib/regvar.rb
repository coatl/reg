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

require 'regdeferred'  #for BlankSlate
require "ron"

module Reg
  def self.minlen_formula regx, session={}
    x=session[regx.__id__] and return x
    session[regx.__id__]="x#{session.size}_"
    
    case regx
    when Repeat; "("+minlen_formula(regx.reg(x), session )+")*"+regx.range.first.to_s
    when Subseq; regx.regs.map{|x| minlen_formula(x, session) }.join'+'
    when Variable; minlen_formula(regx.lit,session)
    when LookAhead,LookBehind; '0'
    when And;    "[#{regx.regs.map{|x| minlen_formula(x, session) }.join', '}].max"
    when Or,Xor; "[#{regx.regs.map{|x| minlen_formula(x, session) }.join', '}].min"
    when Not; (regx.reg.itemrange==(1..1)) ? 1 : 0
    when Many; '0'
    else '1'
    end
    huh
  ensure
    session.delete regx.__id__
  end

  def self.maxlen_formula regx, session={}
    x=session[regx.__id__] and return x
    session[regx.__id__]="x#{session.size}_"
    
    case regx
    when Repeat; "("+maxlen_formula(regx.reg(x), session )+")*"+regx.range.last.to_s
    when Subseq; regx.regs.map{|x| maxlen_formula(x, session) }.join'+'
    when Variable; maxlen_formula(regx.lit,session)
    when LookAhead,LookBehind; '0'
    when And;    "[#{regx.regs.map{|x| maxlen_formula(x, session) }.join', '}].max"
    when Or,Xor; "[#{regx.regs.map{|x| maxlen_formula(x, session) }.join', '}].max"
    when Not; (regx.reg.itemrange==(1..1)) ? 1 : 0
    when Many; 'Infinity'
    else '1'
    end
    huh
  ensure
    session.delete regx.__id__
  end

  class Variable < Fixed
    include Reg,Multiple,Undoable
    #include BlankSlate
    #restore :hash
    
    #fer gawds sake, why BlankSlate??!!!
    
    #we should only be Multiple and Undoable if @to is as well.
    #unfortunately, we don't know what @to is when we construct the Variable,
    #(and its value may change subsequently), so we'll make the conservative
    #assumption that @to is Multiple and Undoable and so we must be also.

    def initialize(*a); 
      super(*a)
      @to=@o #get rid of @to eventually
      @inspect=nil
    end





    def set!(areg)
    
      @to=@o=areg
      @inspect=nil
      class<<self
        def method_missing msg, *args, &block
          @to.send msg, *args, &block
        end
        eval [ :itemrange,:subitemrange,].map {|name|
           "
            def #{name}(*a,&b)
              name='$RegVarItemRangeRecursing#{object_id}'
              if Thread.current[name]
                warning 'hacking itemrange of Reg::var'
                #this is an approximation
                #if I can get an equation solver, this won't hack won't be needed
                (0..Infinity)
              else
                Thread.current[name]=true
                result=@o.#{name}(*a,&b)
                Thread.current[name]=nil
                result
              end
            end
          "
        }.to_s+
        [ :subregs,:to_h].map {|name|
          "
            def #{name}(*a,&b)
              @o.#{name}(*a,&b)
            end
          "
        }.to_s
        
        alias_method :cmatch, :cmatch_jit_compiler if instance_methods.include? "cmatch"
        alias_method :bmatch, :bmatch_jit_compiler if instance_methods.include? "bmatch"
      end
      self
    end
    
    @@inspectcount=0
    def _inspect
      tvname="$RegVarInspectRecursing#{object_id}"
      Thread.current[tvname] or begin
        Thread.current[tvname]=name="var#{@@inspectcount+=1}"
        result="Recursive(#{name}={}, #{@to.inspect})"
        Thread.current[tvname]=nil
        result
      end
    end
    def inspect
      @inspect and return @inspect
      @inspect=_inspect
    end
    
    def formula_value(*ctx) #not sure about this...
      @to
    end
  end

  #a Constant is like a Variable, except it can only be #set! once.
  #Constant should really be the superclass of Variable, not the other way around...
  class Constant < Variable
    def set!(areg)
      super
      def self.set!
        raise TypeError,'Reg::Constant can only be set once'
      end
      result=Ron::Recursive( self, areg )
      freeze
      result
    end
    
    def inspect
      _inspect.sub 'var;', 'const;'
    end

  end

  class <<self
    #Reg::Variable convenience constructor.
    def variable
      ::Reg::Variable.new
    end
    alias var variable

    #Reg::Constant convenience constructor.
    def constant
      ::Reg::Constant.new
    end
    alias const constant
  end


end
