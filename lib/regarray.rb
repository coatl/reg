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

require "assert"
require "pp"
require "forwardable"
require "regdeferred"

module Reg
  module Reg
    def itemrange; 1..1 end  #default match 1 item


    #create a (vector) Reg that will match this pattern repeatedly.
    #(creates a Reg::Repeat.)
    #the argument determines the number of times to match.
    #times may be a positive integer, zero, Infinity, or a
    #range over any of the above. if a range, the lower
    #end may not be Infinity! Reg#- and Reg#+ are shortcuts
    #for the most common cases of multiplting by a range.
    #(at least 0 and at most Infinity.) watch out when
    #multiplying with zero and Infinity (including in a
    #range), as you can easily create a situation where
    #the number of matches to enumerate explodes exponentionaly,
    #or even is infinite. i won't say too much here except
    #that these are generally the same sorts of problems you
    #can run into with Regexps as well.
    def *(times=0..Infinity)
      Repeat.new(self,times)
    end

    #repeat this pattern up to atmost times. could match
    #0 times as the minimum number of matches here is zero.
    def -(atmost=1)
      self*(0..atmost)
    end

    #repeat this pattern atleast times or more
    def +(atleast=1)
      self*(atleast..Infinity)
    end

  end

  #--------------------------
  module Undoable
  
  end
  
  #--------------------------
  module Composite
    include Reg
    def initialize(*args,&block)
      at_construct_time(*args,&block)
#      super
    end
    
    def at_construct_time(*a,&b); end #default does nothing

    def visit_subregs()
      todo=[self]
      visited=Set[]
      while node=todo.shift
        next if visited[node.__id__]
        yield node #visit this node
        visited<<node.__id__
        todo.push(*node.subregs)  #schedule children to be visited
      end
    end
    alias breadth_visit_subregs visit_subregs
  
    def depth_visit_subregs(set=Set[],&visit)
      set[self.__id__] and return
      set<<self.__id__
      subregs.each{|r| r.depth_visit_subregs(set,&visit) }
      visit[self]
    end
  
    def undoable_infection
      unless subregs.grep(Undoable).empty?
        extend Undoable
        class <<self
          undef mmatch
          alias mmatch mmatch_full
        end
      end
    end


    def subregs
      [@reg]
    end
    #includers should define #subregs if they don't have just a single @reg

    protected
    def multiple_infection(*regs)
      regs.empty? and regs=subregs
      regs.each{|reg|
        reg.respond_to? :maybe_multiple and
          reg.maybe_multiple(self)
      }
    end
  end
  
  #--------------------------
  module Multiple
    include Reg
    def ===(other)
      method_missing(:===, other)
    end
=begin
    def maybe_multiple(needsmult) #better name needed
      assert( needsmult.respond_to?( :mmatch))
      class <<needsmult
        undef_method :mmatch
        include Multiple
        #alias mmatch mmatch_full #this doesn't work... why?
        def mmatch(*xx) mmatch_full(*xx); end #have to do this instead
      end
      assert( needsmult.respond_to?( :mmatch))
    end

    def multiple_infection(*args) end  #not needed?
    #we're already multiple; no need to try to become multiple again
=end
    def mmatch(*xx) #multiple match
      abstract
    end

    #negated Reg::Multiple's are automatically lookaheads
    def ~
      ~(Lookahead.new self)
    end


    def starts_with
      abstract
    end

    def ends_with
      abstract
    end

    def matches_class
      raise 'multiple regs match no single class'
    end
  end

  #--------------------------
  module Backtrace
  #  protected

    def regs(ri) @regs[ri] end

    def update_di(di,len); di+len; end
    #--------------------------
    $RegTraceEnable=$RegTraceDisable=nil
    def trace_enabled?
      @trace||=nil
      $RegTraceEnable or (!$RegTraceDisable && @trace)
    end

    #--------------------------
    def trace!
      @trace=true
      self
    end

    #--------------------------
    def notrace!
      @trace=false
      self
    end
  end

  #--------------------------
  if false
  class RR < ::Array
    def inspect
      [self,super].to_s
    end

    def rrflatten
      result=[]
      each{|i|
        case i
          when RR then         result +=i.rrflatten
          when Literal then result << i.unlit
          else                 result << i
        end
      }
    end

    def +(other)
      RR[*super]
    end
  end
  Result=RR
  else
  RR=::Array
  end

 


  #--------------------------
  class Or
    def mmatch(arr,start)
      assert start <= arr.size
      @regs.each_with_index {|reg,i|
        reg===arr[start] and
          return OrMatchSet.new(self,i,nil,1)
      } unless start == arr.size
      return nil
    end

    def itemrange
    if true  
      min,max=Infinity,0
      @regs.each {|r|
        min=r.itemrange.first if Reg===r and min>r.itemrange.first
        max=r.itemrange.last if Reg===r and max<r.itemrange.last
      }
      return min..max
    else
      limits=@regs.map{|r|

        i=(r.respond_to? :itemrange)? r.itemrange : 1..1
        [i.first,i.last]
      }.transpose
      limits.first.sort.first .. limits.last.sort.last
    end
    end

  private
    def mmatch_full(arr,start)
      mat=nil
      @regs.each_with_index{|r,i|
        if r.respond_to? :mmatch
          mat=r.mmatch(arr,start) or next
          if mat.respond_to? :next_match
            return OrMatchSet.new(self,i,mat,mat.next_match(arr,start).last)
          else
            return OrMatchSet.new(self,i,nil,mat.last)
          end
        else
          r===arr[start] and
            return OrMatchSet.new(self,i,nil,1)
        end
      }

      assert mat.nil?
      return nil
    end
  end

  #--------------------------
  class Xor
    def clean_result
      huh
    end

    def itemrange
      #min,max=Infinity,0
      #@regs.each {|r|
      #  min=[min,r.itemrange.first].sort.first
      #  max=[r.itemrange.last,max].sort.last
      #}
      #return min..max
      limits=@regs.map{|r| i=r.itemrange; [i.first,i.last]}.transpose
      limits.first.sort.first .. limits.last.sort.last
    end

  private
if false
    def mmatch_full(arr,start)
      mat=i=nil
      count=0
      @regs.each_with_index{|reg,idx|
        if reg.respond_to? :mmatch
          mat=reg.mmatch(arr,start) or next
        else
          reg===arr[start] or next
          mat=[[arr[start]],1]
        end
        count==0 or return nil
        count=1
        assert mat
      }

      return nil unless mat
      assert count==1
      mat.respond_to? :next_match and return XorMatchSet.new(reg,idx,mat,huh)

      a=RR[nil]*regs.size
      a[idx]=mat[0]
      mat[0]=a
      assert huh
      assert ::Array===mat.first.first
      return mat
    end
end    
    
    def mmatch_full arr, start
      found=nil
      @regs.each{|reg|
        if m=reg.mmatch(arr, start)
          return if found
          found=m
        end
      }
      return found
    end

  end

  #--------------------------
  class And
    include Backtrace #shouldn't this be included only when needed?

    def update_di(di,len) di; end


    def clean_result
      huh
    end


    def enough_matches? matchcnt,*bogus
      matchcnt==@regs.size
    end

    def itemrange
      limits=@regs.map{|r| i=r.itemrange; [i.first,i.last]}.transpose
      limits.first.sort.last .. limits.last.sort.last
    end

  private
    def mmatch_full(arr,start)
    #in this version, at least one of @regs is a multiple reg
      assert( (0..arr.size).include?( start))
      result,*bogus=huh.bt_match(arr,start,0,0,[RR[]])
      result and AndMatchSet.new(self,result)
    end
  end

  #--------------------------
  class Array
    include Reg,Backtrace,Composite

    def max_matches; @regs.size end

    def initialize(*regs)

      #inline subsequences and short fixed repetitions
      iterate=proc{|list|
      result=[]
      list.each{|reg|
        case reg
        when Subseq
          result.push(*iterate[reg.subregs])        
        when Repeat 
          rr=reg.times
          if rr.first==rr.last and rr.first<=3
            result.push(*iterate[[reg.regs(nil)]*rr.first])
          else
            result<<reg
          end
        else result<< Deferred.defang!(reg)
        end
      }
      result
      }
      @regs=iterate[regs]
     # p [:+, :[]]
      super
    end

    class <<self
      alias new__nobooleans new
      def new(*args)
#        args.detect{|o| /^(AND|X?OR)$/.sym===o } or return new__nobooleans(*args)
#        +[/^(AND|X?OR)$/.sym.splitter].match(args)
        Pair===args.first and return ::Reg::OrderedHash.new(*args)
        new__nobooleans(*args)
      end
      alias [] new
    end

    def matches_class; ::Array end

    def subitemrange
      #add the ranges of the individual items
      @subitemrange ||= #some caching...
       begin
        list=Thread.current[:$Reg__Subseq__subitemranges_in_progress]||={}
        id=__id__
        list[id] and throw(id.to_s,0..Infinity)
        list[id]=1
        catch(id.to_s){
        @regs.inject(0){|sum,ob| sum+(Reg===ob ? ob.itemrange.begin : 1) } .. 
          @regs.inject(0){|sum,ob| sum+(Reg===ob ? ob.itemrange.end : 1) }
        }
       ensure
        list.delete id
       end
       
    end

    def multiple_infection(*args) end #never do anything for Reg::Array

    def enough_matches? matchcnt,eof
      matchcnt==@regs.size and eof
    end

    def +(reg)
      if self.class==reg.class 
        self.class.new( *@regs+reg.regs )
      else
        super
      end
    end

    def inspect
      name="$RegInspectRecursing#{object_id}"
      Thread.current[name] and return '+[...]'
      Thread.current[name]=true
      result="+["+ @regs.collect{|r| r.inspect}.join(', ') +"]"
      Thread.current[name]=nil
      result
    end
  
    def subregs; @regs.dup end
  end




end
