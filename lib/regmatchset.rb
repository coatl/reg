=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2016  Caleb Clausen

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

  #--------------------------
  class MatchSet

    def next_match(ary,start)
      abstract
    end

    def deep_copy
      abstract
    end

    def ob_state
      instance_variables.sort.map{|i| instance_variable_get i }
    end

    def ==(other)
      self.class==other.class and ob_state==other.ob_state
    end

  end

  #--------------------------
  class SingleRepeatMatchSet < MatchSet
    def initialize(startcnt,stepper,endcnt)
      endcnt==startcnt and raise 'why even make it a set, then?'
      (endcnt-startcnt)*stepper>0 or raise "tried to make null match set"
      assert startcnt>=0
      assert endcnt>=0
      @matchtimes,@stepper,@endcnt=startcnt,stepper,endcnt
    end

    def next_match(arr,idx)
      assert @stepper.abs == 1
      (@endcnt-@matchtimes)*@stepper>=0 or return nil
      assert @matchtimes >=0
      result=[RR[arr[idx...idx+@matchtimes]], @matchtimes]
      assert ::Array===result.first.first
      @matchtimes+=@stepper
      return result
    end

    def deep_copy
      dup
    end
  end


  #--------------------------
  class OrMatchSet < MatchSet
    def initialize(orreg,idx,set,firstmatchlen)
      @orreg,@idx,@set,@firstmatchlen=orreg,idx,set,firstmatchlen
      assert @firstmatchlen.nil? || Integer===@firstmatchlen
    end

    def ob_state
      instance_variables.map{|i| instance_variable_get i }
    end

    def ==(other)
      OrMatchSet===other and ob_state==other.ob_state
    end

    def next_match(ary,idx)
      if @firstmatchlen
        resultlen,@firstmatchlen=@firstmatchlen,nil
        assert Integer===resultlen
        return [ary[idx,resultlen],resultlen]
      end
      @set and result= @set.next_match(ary,idx)
      while result.nil?
        @idx+=1
        @idx >= @orreg.regs.size and return nil
        x=@orreg.regs[@idx].mmatch(ary,idx)
        @set,result=*if MatchSet===x then [x,x.next_match] else [nil,x] end
      end
      a=RR[nil]*@orreg.regs.size
      a[idx]=result[0]
      result[0]=a
      assert ::Array===result.first.first
      return result
    end

    def deep_copy
      result=OrMatchSet.new(@orreg,@idx,@set && @set.deep_copy,@firstmatchlen)
      assert self==result
      return result
    end
  end
  
  class SingleMatch_MatchSet < MatchSet
  #this is somewhat of a hack, and shouldn't be necessary....
  #it exists because every backtracking stop has to have a 
  #matchset in it, even the ones that only match one way. 
  #this class encapsulates matchsets that match only one way.
    def initialize; end
    def next_match*; end
  end


 #--------------------------
  class RepeatMatchSet < MatchSet
  
    attr :progress
    def initialize(progress,consumed) 
      @progress=progress
      #@cnt=@startcnt-stepper
      #@ary.push 1
      @consumed=consumed
      @firstmatch=[progress.clean_result,@consumed]
      assert( progress.matcher.times===progress.regsidx)
      assert progress.regsidx
      #assert(@ri==@firstmatch.first.size)
    end

    def match_iterations;
      #assert(@ri==Backtrace.clean_result(@ary).size)
      progress.regsidx
    end

    #very nearly identical to SubseqMatchSet#next_match
    def next_match(arr,idx)
      #fewer assertions in twin
      if @firstmatch
        result,@firstmatch=@firstmatch,nil
        assert result.first.empty? || ::Array===result.first.first
        #print "idx=#{idx}, inc=#{result.last}, arr.size=#{arr.size}\n"
#        assert idx+result.last<=arr.size
#        assert(progress.regsidx==result.first.size) 
        return result
      end
      
      @progress or return #not in twin ... ignore it
      
      assert progress.check_result

      i=@context.position_inc
=begin extents not used      
      extents= if i==0
        []
      else
        progress.position_stack[-i..-1]
      end
=end
            #this part's not in twin
      #'need to check for fewer matches here before rematching last matchset'
      
      #what if the match that gets discarded was returned by a matchset
      #that has more matches in it?
      #in that case, i is 1 and the body of this if should not be executed...      
      if @context.regsidx>@context.matcher.times.begin  #&& i>1
        progress.backup_stacks(@context) or raise
        huh #need to change progress.cursor.pos here too
        #result of backup_stacks is abandoned, leaked, orphaned
        #we don't want it anymore
        #but what if it's nil?
        
        #but now i need to undo all other progress state too, if 
        #the state was created with the match result just popped.
        #in general, it's not possible to distinguish state with the 
        #last match from state with the matches that might have preceeded it...
        #unless I create a backtracking point for each optional iteration
        #of the repeat matcher.
        #currently, making a backtracking point implies making a matchset
        #as well. I'll need a matchset the contains only 1 match.
        #ok, i think this is working now. no extra code needed here.
        
        @consumed-=pos-progress.position_stack.last
        #assert(@ri==Backtrace.clean_result(@ary).size)
        assert idx+@consumed<=arr.size
        assert progress.check_result
        result= [progress.clean_result, @consumed]
        assert progress.check_result
        return result
      end


        assert progress.check_result
      assert( (0..@progress.matcher.max_matches)===@progress.regsidx)
      result,di,ri=progress.last_next_match
      if result and @progress.matcher.enough_matches? ri #condition slightly different in twin
        result=[progress.clean_result,di]
        @consumed=di  #not in twin...why?
        #@progress.regsidx-=1
        assert ::Array===result.first.first
        assert idx+result.last<=arr.size
        assert progress.check_result
        #assert(@ri==result.first.size)
        return result
      end

      assert( (0..@progress.matcher.max_matches)===@progress.regsidx)
      #assert(@ri==Backtrace.clean_result(@ary).size)
      assert(progress.check_result)
      


      @progress.matchset_stack.empty? and return @progress=nil  #also checking @ary in twin... ignore it
        assert @progress.regsidx>0
        
      @progress.backtrack or return @progress=nil #@progress never set to nil like this in twin... ignore it

      #this is where the divergence widens. ri is a local in twin
 
        #assert(@ri==Backtrace.clean_result(@ary).size)
      assert(progress.check_result)
        mat,di,@ri=@progress.bt_match #mat is @ary in twin
        mat.nil? and return @progress=nil

        #assert(@ri==Backtrace.clean_result(mat).size)
        assert @progress.regsidx
      assert( (0..@progress.matcher.max_matches)===@progress.regsidx)

      result=[@progress.clean_result,di]
      @consumed=di  #no @consumed in twin
      assert ::Array===result.first.first
      assert idx+result.last<=arr.size
        assert progress.check_result
        #assert(@ri==result.last.size)
      return result
    end

  end

  #---------------------------------------------
  class SubseqMatchSet < MatchSet
    
    def initialize progress,di;
      @reg,@progress= progress.matcher,progress
      
      @orig_pos=progress.cursor.pos-di
      @firstresult= [progress.clean_result,di]
    end
 
 #(@reg=>progress.matcher,@matchary=>progress.huh,di=>progress.cursor.pos-@orig_pos)
 
    def next_match(ary,start)
      if @firstresult
        @firstresult,result=nil,@firstresult
        assert ::Array===result.first.first
        return result
      end

   
      result,di,ri=@progress.last_next_match
      result or return @progress=nil      
      if result and ri==@reg.max_matches
        result=[@progress.clean_result,di]
        assert ::Array===result.first.first
        return result
      end
      

      (@progress and !@progress.matchset_stack.empty?) or return @progress=nil
      assert @progress.regsidx
      @progress.backtrack or return @progress=nil

      #need to adjust ri?

      #is this right... dunno...
      result,di,bogus=@progress.bt_match


      if result
        result=[@progress.clean_result,di]
        assert ::Array===result.first.first
        return result
      end
    end
    
    def match_iterations
      progress.matcher.max_matches
    end
    
  end
  #--------------------------
  class AndMatchSet < SubseqMatchSet
    #this isn't really right...
    #on next_match, we need to backtrack the longest alternative(s)
    #if they're then shorter than the next longest alternative, 
    #then that (formerly next longest) alternative becomes
    #the dominating alternative, and determines how much is consumed
  
  end
  #might need Reg::Or tooo....


  #--------------------------
  class ReplaceMatchSet < MatchSet
    def initialize(replacer, progress, origpos, ms)
      @replacer,@progress,@origpos,@ms=replacer,@progress,origpos,ms
    end
    
    def next_match(*args)
      result=@ms.next_match(*args)
      @replacer.replace @origpos,result.last,@progress
      return result
    end
  
  end

  

end
