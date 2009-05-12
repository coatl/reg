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

module Reg
  module Reg
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
  end

  module Backtrace
    #--------------------------
    def Backtrace.clean_result(result,restype=RR)
      assert result.size%3==1
      a=[]
      0.step(result.size-1,3) {|i|
        assert RR===result[i]
        assert result[i].empty? || ::Array===result[i].first
        a+= result[i]
        assert a.empty? || a.first.empty? || ::Array===a.first
      }
      assert a.empty? || a.first.empty? || ::Array===a.first
      return restype[*a]
    end

    #--------------------------
    def Backtrace.check_result(result)
      assert result.size%3==1
      last_idx=0
      0.step(result.size-1,3) {|i|
        assert RR===result[i]
        assert result[i].empty? || ::Array===result[i].first
        next if i==0
        assert MatchSet===result[i-2]
        assert Integer===result[i-1]
        assert result[i-1]>=last_idx
      }
      true
    end


    #--------------------------
    def Backtrace.deep_copy(res)
      #arr, matchset, num, arr

      assert res.size%3==1
      assert ::Array===res.first
      result=[res.first.dup]
      (1...res.size).step(3) do |n|
        ms,num,arr=res[n,3]
        assert ms
        result+=[ms.deep_copy,num,arr.dup]
        result[-3]==ms or (pp :ms_o, ms.ob_state, :r_3_o, result[-3].ob_state, :ms, ms, :r_3, result[-3])
        assert(result[-3]==ms)
      end
      assert result==res
      assert Backtrace.check_result( result)
      return result
    end


    #--------------------------
    #bt, in this case, stands for 'backtracking'.
    #but the cognosceni refer to this function as 'bitch-match'.
    def bt_match(arr,start,ri,di,result,regs_size=max_matches)
      assert start+di <= arr.size
      assert start >= 0
      assert di >= 0
      assert( (0..regs_size)===ri)
      assert ::Array===result.first
      assert Backtrace.check_result( result)
      loop do #loop over regs to match
        assert start+di <= arr.size
        assert di >= 0
        assert( (0..regs_size)===ri)

        trace_enabled? and $stderr.print start, " ", self.inspect, ": ", Backtrace.clean_result(result).inspect, "\n"
        assert Backtrace.check_result result

        #try a new match of current reg
        r=regs(ri)
        if r.respond_to? :mmatch
              # 'mmatch could return 2 items here'
              m=r.mmatch(arr,start+di)
              #is a single match or a match set?
              unless m.respond_to? :next_match
                mat,matchlen=*m #single match or nil
              else
                #it's a set -- start new inner result array
                #with initial match as first elem
                result += [m,di,[]]
                mat,matchlen=m.next_match(arr,start+di)
                assert mat
              end
        else
          if start+di<arr.size && r===arr[start+di]
            mat=RR[arr[start+di]]
          end
        end


        assert Backtrace.check_result result

        unless mat #match fail?
          assert Backtrace.check_result result
          return result,di,ri if enough_matches? ri

          #doesn't match, try backtracing
          ri,di=backtrace(arr,start,result,ri)
          ri or return nil #bt failed? we fail
          assert(start+di<=arr.size)
          assert Backtrace.check_result result
        else  #match succeeded
          #advance to next reg
          ri+=1
          result.last<<mat
          assert ::Array===result.first
          matchlen ||= mat.length
          di=update_di(di,matchlen)
          assert(start+di<=arr.size)
        end

        assert( (0..regs_size)===ri)
        assert(start+di<=arr.size)

        assert Backtrace.check_result result
        return result,di,ri if ri==regs_size

      end #loop

    end

    #--------------------------
    def backtrace(arr,start,result,ri)
      assert ri != Infinity
      assert(Backtrace.check_result result)
      mat,matlen,di=nil
      loop do #might have to bt multiple times if prev prelim set also fails
        #get result set and
        #reset data idx to start of last prelim set
        ms,di=result[-3..-2]

        unless ms #if result underflowing we fail
          assert(result.size==1)
          #we must have b'trace'd thru the last prelim result set
          #no more alternatives; finally fail
          return nil
        end

        ri-=result.last.size  #reset result idx

        assert(ri>=0)

        assert(result.size%3==1)
        assert(result.size>=3)
        assert start+di <= arr.size
        mat,matlen=ms.next_match(arr,start+di)
  #      pp ms
        mat and break(assert( (0..max_matches)===ri+1))
        result.slice!(-3..-1).size==3 or raise 'partial result underflow'
      end

      assert ::Array===mat
      assert ::Array===mat.first
      assert start+update_di(di,matlen) <= arr.size

      #adjust ri,di,and result to include mat
      ri+=1
      result[-1]=[mat]
      di= update_di(di,matlen)

      assert start+di <= arr.size
      #assert(Backtrace.check_result mat)
      return ri,di
    end
  end

  class MatchSet
    def last_next_match(ary,start,resfrag)
      r,di=resfrag[-3..-2]
      r or return nil,nil,match_iterations

      #dunno how to do this simply...
      #assert full_up? if SubseqMatchSet===self

      r,diinc=r.next_match(ary,start+di)
      unless r
        discarding=resfrag.last
        resfrag.slice!(-3..-1).size==3 or raise :impossible
        
        #might need to return non-nil here, if resfrag isn't exhausted yet
        ri=match_iterations-discarding.size
        return nil,nil,ri unless @reg.enough_matches? ri
        return resfrag, di, ri
      end

        assert di+diinc <= ary.size
      di+=diinc
      ri=match_iterations-resfrag[-1].size+1 #+1 for r, which must match here if set
      resfrag[-1]=[r]
      if ri<@reg.max_matches  #if there are more subregs of this reg to be matched
        #re-match tail regs
        assert di <= ary.size
        #di is sometimes bad here, it seems....(fixed now?)
        resfrag,di,ri=@reg.bt_match(ary,start,ri,di,resfrag)
      end
      
           return resfrag,di,ri
    end
  end
 #--------------------------
  class RepeatMatchSet < MatchSet
    def initialize(regrepeat,ary,ri,diinc) #maybe rename diinc=>di
      @reg,@ary,@ri,@diinc=regrepeat,ary,ri,diinc
      #@cnt=@startcnt-stepper
      #@ary.push 1
      @firstmatch=[Backtrace.clean_result(ary),@diinc]
      assert( @reg.times===@ri)
      assert @ri
      #assert(@ri==@firstmatch.first.size)
    end

    def match_iterations;
      #assert(@ri==Backtrace.clean_result(@ary).size)
      @ri
    end

    #very nearly identical to SubseqMatchSet#next_match
    def next_match(arr,idx)
      #fewer assertions in twin
      if @firstmatch
        result,@firstmatch=@firstmatch,nil
        assert result.first.empty? || ::Array===result.first.first
        #print "idx=#{idx}, inc=#{result.last}, arr.size=#{arr.size}\n"
        assert idx+result.last<=arr.size
        assert(@ri==result.first.size)
        return result
      end

      @ary or return nil #not in twin ... ignore it

      #this part's not in twin
      #'need to check for fewer matches here before rematching last matchset'
      
      #uwhat if the match that gets dicarded was returned by a matchset
      #that has more matches in it? in that case nothing should be done...
      #in that case, @ary.last.size is 1 and the body is not executed...
      if @ri>@reg.times.begin  && @ary.last.size>1
        @ri-=1
        discarding=@ary.last.pop
        @diinc-=discarding.last.size
        #assert(@ri==Backtrace.clean_result(@ary).size)
        assert idx+@ri<=arr.size
        return [Backtrace.clean_result(@ary), @diinc]
      end


      result,di,@ri=last_next_match(arr,idx,@ary)
      if result and @reg.times===@ri #condition slightly different in twin
        result=[Backtrace.clean_result(@ary=result),di]
        @diinc=di  #not in twin...why?
        assert @ri
        assert ::Array===result.first.first
        assert idx+result.last<=arr.size
        #assert(@ri==result.first.size)
        return result
      end

      assert( (0..@reg.max_matches)===@ri)
      #assert(@ri==Backtrace.clean_result(@ary).size)
      assert(Backtrace.check_result @ary)
      


      @ary[-2] or return @ary=nil  #also checking @ary in twin... ignore it
        assert @ri>0
       
      @ri,di=@reg.backtrace(arr,idx,@ary, @ri) #last param is @reg.max_matches in twin
      #this is where the divergence widens. @ri is a local in twin
      @ri or return @ary=nil #@ary never set to nil like this in twin... ignore it

      #huh 'need to adjust @ri?' #why?

        #assert(@ri==Backtrace.clean_result(@ary).size)
      assert(Backtrace.check_result @ary)
        mat,di,@ri=@reg.bt_match(arr,idx,@ri,di,@ary) #mat is @ary in twin
        mat.nil? and return @ary=nil

      #huh#is @ri right here? how do i know?

        #assert(@ri==Backtrace.clean_result(mat).size)
        assert @ri
      assert( (0..@reg.max_matches)===@ri)
      #assert(mat.equal? @ary) #wronggo
      @ary=mat

      result=[Backtrace.clean_result(mat),di]
      @diinc=di  #no @diinc in twin
      assert ::Array===result.first.first
      assert idx+result.last<=arr.size
        #assert(@ri==result.last.size)
      return result
    end

    def deep_copy
        #assert(@ri==Backtrace.clean_result(@ary).size)
      assert( (0..@reg.max_matches)===@ri)
      res=RepeatMatchSet.new @reg,Backtrace.deep_copy(@ary),@ri,@diinc
      fm  =@firstmatch && @firstmatch.dup
      res.instance_eval { @firstmatch=fm } 
      return res
    end
  end

  class Repeat
    def mmatch(arr,start)
      i=-1
      (0...@times.end).each do |i|
        start+i<arr.size or break(i-=1)
        @reg===arr[start+i] or break(i-=1)
      end
      i+=1
      assert(   (0..@times.end)===i)
      if i==@times.begin
        return [RR[arr[start,i]], i]
      end
      i>@times.begin or return nil
      return SingleRepeatMatchSet.new(i,-1,@times.begin)
    end

    def mmatch_full(arr,start)
      assert start <= arr.size
      r=[RR[]]

      #first match the minimum number
      if @times.begin==0 #if we can match nothing
        arr.size==start and return [r,0] #at end of input? return empty set
        ri=di=0
      else
        arr.size==start and return nil
        assert @times.begin<Infinity
        r,di,ri=bt_match(arr,start,0,0,r,@times.begin)  #matches @reg @times.begin times
        r.nil? and return nil
      end
      assert ri==@times.begin

      assert !@times.exclude_end?
      left=@times.end-@times.begin

      #note: left and top could be infinite here...

      #do the optional match iterations
      #only greedy matching implemented for now
      #there must be a more efficient algorithm...
      if left >= 1
        assert Backtrace.check_result r
        #get remaining matches up to @times.end times
        #why the deep_copy here?
        #because bt_match could change the rr argument, and 
        #we might need to return the original in r below
        res,di,ri=bt_match(arr,start,ri,di,rr=Backtrace.deep_copy(r))
        assert Backtrace.check_result res
        assert @times===ri
        
        #res is not right type! --yes it is
        res and return RepeatMatchSet.new(self,res,ri,di)
      end

      #if matchset has no backtracking stops, and 
      #hence cannot contain more than one actual match,
      #then just return that match.
      r.size>1 ? RepeatMatchSet.new(self,r,ri,di) :
        [Backtrace.clean_result(r),di]
    end
  end
  
  class Subseq
      def mmatch(arr,start)
    #in this version, each of @regs is not a multiple reg
      assert start<=arr.size
      start+@regs.size<=arr.size or return nil
      idx=0
      @regs.each do |reg|
        assert(start+idx<arr.size)
        reg===arr[start+idx] or return nil
        idx+=1
      end
      return [RR[arr[start,@regs.size]], @regs.size]
    end
    
    def mmatch_full(arr,start)
    #in this version, at least one of @regs is a multiple reg
      #start==arr.size and huh
      assert( (0..arr.size).include?( start))
      result,di,bogus=bt_match(arr,start,0,0,[RR[]])
      result and SubseqMatchSet.new(self,result,di)
    end
  end
    #--------------------------
  class SubseqMatchSet < MatchSet
    def initialize(subseqreg,matchary,di)
      @reg,@matchary=subseqreg,matchary
      @firstresult= [Backtrace.clean_result(@matchary),di]
    end

    def match_iterations; @reg.max_matches end

    def next_match(ary,start)
      if @firstresult
        @firstresult,result=nil,@firstresult
        assert ::Array===result.first.first
        return result
      end
      result,di,ri=last_next_match(ary,start,@matchary)
      if result and ri==@reg.max_matches
        result=[Backtrace.clean_result(@matchary=result),di]
        assert ::Array===result.first.first
        return result
      end

      (@matchary and @matchary[-2]) or return nil
      ri,di=@reg.backtrace(ary,start,@matchary, @reg.max_matches)
      ri or return nil

      #need to adjust ri?

      #is this right... dunno...
      @matchary,di,bogus=@reg.bt_match(ary,start,ri,di,@matchary)


      if @matchary
        result=[Backtrace.clean_result(@matchary),di]
        assert ::Array===result.first.first
        return result
      end
    end

    def deep_copy
      resfrag=Backtrace.deep_copy(@matchary)
      result=dup
      result.instance_eval{@matchary=resfrag}
      return result
    end

    def subregs; @regs.dup end
  end

  #--------------------------
  class AndMatchSet < SubseqMatchSet
    #this isn't really right...
    #on next_match, we need to backtrack the longest alternative(s)
    #if they're then shorter than the next longest alternative, 
    #then that (formerly next longest) alternative becomes
    #the dominating alternative, and determines how much is consumed
  
  end

  class Array
    def ===(other)
      ::Array===other or return false
      result,di,bogus=bt_match(other,0,0,0,[RR[]])
      assert di.nil? || di <= other.size
      return(di==other.size && Backtrace.clean_result(result,::Array))
    end
  end

end
