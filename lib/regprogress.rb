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
begin require 'rubygems'; rescue Exception; end

#$:<<"../sequence/lib"  #temp hack
#require 'warning'
#warning "sequence found via temporary hack"
#$MMATCH_PROGRESS=1

require 'forwardable'

require 'sequence'
require 'sequence/indexed'



=begin the internal api
originally:
ResAryFrag=Array #it would be nice to get a more precise definition....
ResAry=+[ResAryFrag,-[MatchSet,Integer,ResAryFrag].*]

Reg%:mmatch[Array,Integer,
  Returns( MatchSet|ResAryFrag|nil)
]
Backtrace%:bt_match[Array,Integer,Integer,Integer,ResAry,Integer.-, 
  Returns( ResAry|nil,Integer,Integer)
]
MatchSet%:next_match[Array,Integer,
  Returns( ResAryFrag|nil,Integer)
]

currently:
Reg%:mmatch[Progress,  #has to change to take progress soon
  Returns( MatchSet|ResAryFrag|nil)
]  #except subseq and repeat currently want progress
Progress%:bt_match[Integer.-,   #affects progress, i'm pretty sure
  Returns( ResAry|nil,Integer,Integer)  #1st result used only as bool
]
MatchSet%:next_match[Array,Integer,  #affects progress? #needs to change too
  Returns( ResAryFrag|nil,Integer)
]
MatchSet%:initialize[Progress,OBS,Returns( MatchSet)] #for every ms class



former ultimate goal:
Reg%:mmatch[Progress,  Returns( MatchSet|Integer|nil)]  #affects progress on success (when integer returned)
Progress%:bt_match[Integer.-,   Returns( Bool)]  #affects progress on success
MatchSet%:next_match[Returns( Integer|nil)]   #affects progress on success
#(modified progress is the same one as was given to the mmatch that created the matchset)
MatchSet%:initialize[Progress,OBS,Returns( MatchSet)] #for every ms class
          


now:
Reg%:cmatch[Progress, Yields[NeverReturns], NeverReturns] #throws :RegMatchFail on match failure, yields on success.
Reg%:bmatch[Progress, Returns(Object)] #returns a true value on success, nil or false on match failure


=end


#---------------------------------------------
module Reg

  #---------------------------------------------
  class MatchFailRec
    attr_accessor :undos_inc,:matchsucceed_inc#,:position_inc
    def initialize
      @undos_inc=@matchsucceed_inc=0;#@position_inc=0
    end
    
    #position_inc is the number of positions to pop off position stack
    #to get back to the point before the match of the most recent matchset.
    #it is also the count by which to adjust regsidx to get back to the 
    #corresponding reg which generated the matchset.
#    alias regs_adjust position_inc
  end

  #---------------------------------------------
  class Progress
#    attr_reader :matcher, :cursor, :regsidx
    attr_reader :variables
    
    #for internal use only...
#    attr_writer :undos_stack, :matchfail_todo, :matchsucceed_stack #, :regsidx
       
       
    #matchset_stack and matchfail_todo are (nearly) parallel arrays; matchfail_todo has
    #one more item in it (at the bottom). each matchfailrec represents the things to undo 
    #on failure to get back to the corresponding matchset's starting position.
    
    #matchfail_todo is more or less a 2-dimensional array of integers. very many of
    #those integers in the undos_inc and matchsucceed_inc columns will be zero. it
    #would be nice to use a sparse vector or matrix instead.
    
    #a progress has a stack of contexts
    #a context  has a (possibly empty) stack of matchsets
    #a matchset has a context
    
    
    
    #---------------------------------------------
    class Context
      def initialize matcher,data
        @matcher=matcher
        @data=data
        @regsidx=0
        @position_stack=[data.pos]
        @position_inc_stack=[0]
#        @matchfail_todo=[MatchFailRec.new]
#        @matchset_stack=[]
      end
      attr_reader :matcher,:data,:regsidx,:position_stack#,:matchfail_todo,:matchset_stack
      attr_reader :context_type

      #position_inc_stack.last is the number of patterns that have successfully matched
      #since the last matchset was pushed onto matchset_stack. The pattern that created
      #the last matchset is included in this count, hence position_inc_stack.last must
      #always be 1 or greater, unless position_inc_stack contains one element. 
      attr_reader :position_inc_stack
      
      attr_writer :regsidx,:data
      alias cursor data
      
      attr_accessor :context_index
      
      #---------------------------------------------
      def with_context(type,data)
        @context_type=type
        @data=::Sequence::SingleItem.new data
      end
      
      #---------------------------------------------
      def get_index
        context_index || data.pos
      end
      #---------------------------------------------
      def position_inc; position_inc_stack.last end
    
      #---------------------------------------------
      def push_match(inc=0)
        #matchset_stack should be 1 smaller than matchfail_todo
        #assert matchfail_todo.size-1==matchset_stack.size

        cursor.move inc  #do nothing if no param given
        assert cursor.pos>= position_stack.last
        position_stack.push cursor.pos  #push the start position of the next match
        position_inc_stack[-1]+=1
        self.regsidx+=1
      end
      
      #---------------------------------------------
      def origpos
        position_stack.first
      end

      #---------------------------------------------
      def posinc
        cursor.pos-origpos
      end
    end
    
      attr_reader :matchfail_todo,:matchset_stack
    extend Forwardable
    def_delegators "@context_stack.last", :matcher,:regsidx,:regsidx=, :with_context,
      :data,:get_index,:position_stack,:push_match,#:matchfail_todo,:matchset_stack,
      :context_type, :context_index, :context_index=, :position_inc_stack, :position_inc,
      :origpos, :posinc
    alias cursor data
    alias regs_adjust position_inc
    def_delegators :cursor,   :move, 
      :scan, :skip, :check, :match?, 
      :scan_until, :skip_until, :check_until, :exist?,
      :scanback, :skipback, :checkback, :matchback?, 
      :scanback_until, :skipback_until, :checkback_until, :existback?
          
    
    def context; @context_stack.last end
    
    def sequence; cursor; end

    #---------------------------------------------
    def initialize(matcher,cursor)
#      @parent=nil      #eliminate
#      @matcher=matcher #move into Context
#      @regsidx=0       #move into Context
#      @cursor=cursor   #move into Context
      @context_stack=[]
      newcontext matcher, cursor
      @matchset_stack=[]
      @matchfail_todo=[MatchFailRec.new]  #list of things to do when match fails.... 
                  #undo(&adjust variables), matchsucceed, position, (matchset)
#      @position_stack=[@cursor.pos] #r-list? of positions
      @variables={}
      @undos_stack=[] #recursive list of undo procs and vars defined in this entire match
      @matchsucceed_stack=[] #r-list of things to do when entire match succeeds... subst and deferreds
      
     
#      assert check_result
    end
  
    #---------------------------------------------
    def newcontext(matcher,data=cursor)
      @context_stack.push Context.new(matcher,data)
      return nil
    end
    #a new context is created (newcontext is called) whenever entering
    #a Subseq, Repeat, vector logical, and sometimes composite scalar 
    #classes such as Reg::Object, Reg::Array, Reg::Hash, Reg::Restrict, 
    #(or even a scalar logical)
    #_if_ they contain an undo, variable binding, later or replacement 
    #(Reg::Transform, Reg::Undo, Reg::Later, or Reg::Bound)
    #expression somewhere within them. 
    #once the expression that created the context is finished matching, it is popped 
    #from the context stack. however, a reference to it may remain from
    #a MatchSet on the matchset_stack. (if there was a backtracking stop 
    #found during the (sub)match, there will be such a reference.)
    
    #why should vector logicals create a new context?? now i think that was a mistake....
  
    #---------------------------------------------
    def endcontext; @context_stack.pop end
        
    #---------------------------------------------
    def push_matchset(ms=nil)
#      assert check_result
      assert MatchSet===ms if defined? MatchSet
      matchset_stack.push ms
      matchfail_todo.push MatchFailRec.new
      position_inc_stack.push 0
#      assert check_result
      #push_match len  #disable... caller wants to do it...
    end

=begin
    #---------------------------------------------
    #dunno if i really want this
    def skip(mtr) 
      len=(cursor.skip mtr) || return
      push_match len
      return len
    end
=end
    

    #---------------------------------------------
    #this method is dangerous! it leaves the Progress in an inconsistant state.
    #caller must fixup state by either popping matchset_stack or pushing a matchfail_todo.
    #called by last_next_match, backtrack, and next_match of RepeatMatchSet and SubseqMatchSet
    def backup_stacks(ctx=context)
      (ctx.position_inc_stack.size > 1) or return
      assert(ctx.position_inc_stack.size > 1)
      discarding_pos=ctx.position_inc_stack.pop
      assert(ctx.position_inc_stack.size > 0)
      ctx.regsidx-=discarding_pos #adjust position in matcher
      assert(ctx.position_stack.size >= discarding_pos) #what if position stack is empty here?
      
      ctx.position_stack.slice!(-discarding_pos..-1) if discarding_pos>0
#     @position_stack=@position_stack.slice(0...-discarding.position_inc)

      assert(matchfail_todo.size >= 1)
      discarding=matchfail_todo.pop

      #backup undo stack and execute undos
      discarding_undos=discarding.undos_inc
      process_undos @undos_stack.slice!(-discarding_undos..-1) if discarding_undos>0

      #backup matchsucceed stack
      discarding_succ=discarding.matchsucceed_inc
      @matchsucceed_stack.slice!(-discarding_succ..-1) if discarding_succ>0

      return matchset_stack.pop
    end
    
     
    #---------------------------------------------
    def backtrack(ctx=context)
      assert regsidx != Infinity
      assert check_result
      mat=nil
      loop do
        #warn "warning: ctx.position_stack not being updated in backup_stacks?"
        ms=backup_stacks(ctx) or return 
        
        if mat=ms.next_match(cursor.data, position_stack.last)
          matchset_stack.push ms
          #position_inc_stack.push 0   #i'm really unsure about this line
          #warn "warning: ctx.position_stack not being updated??"
          break
        end
      end
      assert( (1..matcher.max_matches)===regsidx+1)
      assert ::Array===mat
      #assert ::Array===mat.first


      #back up cursor position 
      ctx.cursor.pos=ctx.position_stack.last
      
      
      
      matchfail_todo.push MatchFailRec.new
      ctx.position_inc_stack.push 0   #i'm really unsure about this line
      ctx.push_match mat.last
      
      assert regsidx
      assert check_result
      return ctx.regsidx, ctx.cursor.pos-ctx.origpos
    end
  
    #---------------------------------------------
    #lookup something that was already matched, either by
    #name or index(es).
    #probably need to take a full path for parameters
    def backref; huh end
     
    def set_state!(cu,ps,mtr,parent) #internal use only
      @parent=parent
    #  @matchfail_todo=[MatchFailRec.new]
    #  @matchset_stack=[]#@matchset_stack.dup
    #  @cursor=cu
    #  @position_stack=ps
    #  @undos_stack=[]
    #  @matchsucceed_stack=[]
    #  @variables=@variables.dup

#      @matchfail_todo.last.position_inc+=1
#      @matchfail_todo.last.undos_inc+=1
      
      if mtr
        @matcher=mtr#@matcher might be set to soemthing different
        @regsidx=0
      end
    end
        
    #---------------------------------------------
    def subprogress(cu=nil,mtr=nil)
#      warn 'subprogress not quite thought out...'
      huh "replace this method with newcontext/endcontext"
      result=dup
      result.set_state!(        if cu
          unless ::Sequence===cu
            ::Sequence.from(cu) #convert other data to a cursor...
          else
            cu
          end
        else
          result.cursor.position       # make a sub-cursor 
          #make real SubCursor here?
        end, [result.cursor.pos], mtr,self )

      #should this be in self, or result?
      
      assert result.check_result
      
      result
    end
    
    #---------------------------------------------
    def make_hash
      warn "warning: i want more here..."
            hash
    end
       
    #---------------------------------------------
    def last_match_range
      position_stack[-2]...position_stack[-1]
    end
    
    #---------------------------------------------
    def top_matchset
      matchset_stack.last
    end
    
    #---------------------------------------------
    def variable_names
      @variables.keys
    end
    
    #---------------------------------------------
    def raw_variable(name)
      assert ::Symbol.reg|::String===name
      var=@variables[name] and var.last    
    end
    
    #---------------------------------------------
    #always returns array or string, not single item
    def lookup_var(name)
      assert ::Symbol.reg|::String===name
      var=@variables[name] and (cu,idx=*var.last) and cu and cu[idx]
    end
    alias [] lookup_var
    
    #---------------------------------------------
    def unregister_var(name)
      assert ::Symbol.reg|::String===name
      @variables[name].pop
      assert @undos_stack.last.equal?( name ) #maybe this isn't true????....
      @undos_stack.pop
      matchfail_todo.last.undos_inc-=1
      assert matchfail_todo.last.undos_inc>=0
      nil
    end
    #---------------------------------------------
    def raw_register_var(name,bound_to)
      assert ::Symbol.reg|::String===name
      @variables[name]||=[]
      #@variables[name] and warn( "variable #{name} is already defined")
      @variables[name].push bound_to
      @undos_stack<<name
      matchfail_todo.last.undos_inc+=1
    end

    #---------------------------------------------
    def register_var(name,bound_to)
      assert ::Symbol.reg|::String===name
      @variables[name]||=[]
      #@variables[name] and warn( "variable #{name} is already defined")
      @variables[name].push [@cursor,bound_to]
      @undos_stack<<name
      matchfail_todo.last.undos_inc+=1
    end

    #---------------------------------------------
    def bindhistory(sym)
      @variables[sym].map{|(cu,idx)| cu[idx]}
    end
    
    #---------------------------------------------
    def register_undo *args, &block
      @undos_stack<<proc{block[*args]}
      matchfail_todo.last.undos_inc+=1
    end

    #---------------------------------------------
    def process_undos(undos=@undos_stack)
      #i think regular reverse_each will work as well...
      Ron::GraphWalk.recursive_reverse_each undos do|undo| 
        ::Symbol.reg|::String===undo ? @variables[undo].pop : undo.call 
      end
    end


    #---------------------------------------------
    def register_replace(index,len,rep_exp) 
      huh #hmmm.... may need some work. what is context_type defined as?
      @matchsucceed_stack.push context_type.new(context.data,index,len) {|gp|
        Replace.evaluate(rep_exp,self,gp)
      }
      matchfail_todo.last.matchsucceed_inc+=1
    end

    #---------------------------------------------
    def register_later(*args,&block)
      @matchsucceed_stack.push proc{block[*args]}
      matchfail_todo.last.matchsucceed_inc+=1
    end

    #---------------------------------------------
    def process_laters
      #i think regular reverse_each will work as well...
      Ron::GraphWalk.recursive_reverse_each(@matchsucceed_stack) {|later| later.call }
    end

=begin
  #---------------------------------------------
  class Later #inside Progress, so it doesn't conflict with Reg::Later from regreplace.rb
    def initialize(block,args)
      @block,@args=block,args
    end
    class<<self; 
      alias [] new; 
    end
    
    def call
      @block.call( *@args)
    end
  end
=end


    #--------------------------
    $RegTraceEnable=$RegTraceDisable=nil
    def trace_enabled?
      @trace||=nil
      $RegTraceEnable or (!$RegTraceDisable && @trace)
    end

    #--------------------------
    #bt, in this case, stands for 'backtracking'.
    #but the cognoscenti refer to this method as 'bitch-match'.
    #match the multiple matcher mtr against the input data in current #cursor
    #but backtracking all along if any submatches fail
    #remember, a multiple matcher has many sub-reg expressions
    #(or in the case of Reg::Repeat, one expression used multiple times)
    #that each have to match the input at some point. (sequentially one after
    #another in the case of Repeat and Subseq, all at the same point in input
    #in the case of Reg::And.) 
    
    #returns nil if no match, or if a match is found, returns
    #[true, # of data items consumed, number of matchers used ( - 1?)]
    
    #used in #mmatch_full of Reg::Array, Reg::Subseq, Reg::Repeat, Reg::And
    #and in the corresponding MatchSets
    #also in #last_next_match
    
    #The Reg::And version employs a trick (defining #update_di to leave di unchanged)
    #that will ensure each sub-reg starts at the same place in #cursor as the first one.
    
    #Reg::Or and Reg::Xor start each sub-reg at the same place as well, but effectively
    #only one sub-reg of Reg::Or or Reg::Xor ever matches input overall. With Xor, it must
    #be guaranteed that only one alternative can match at all at the current position in
    #input. With Or, #mmatch kicks out early once the first successful match is found. 
    #subsequent matches in the overall expression might fail, causing the Or to be backtracked
    #into and a different alternative to be considered, but in that case, the first alternative
    #is considered to have failed overall, and any side effects in it are undone.
    
    #why is this important? Reg::And must call bt_match, because a Variable
    #binding in one branch might be used in a subsequent branch of the overall expression.
    #with Reg::Or and Xor, that cannot be the case, and hence they need not call bt_match
    
    #backtracking stops
    #a subexpression that might match multiple things in the current input creates a 
    #backtracking stop within the current Progress (self). creating a new backtracking 
    #stop means by an entry on both @matchset_stack and @matchfail_todo and #position_inc_stack. 
    
    #bt_match returns 3 things if an initial match could be found:
    #true, 
    #the number of data items in cursor to be consumed in the initial match, and
    #the number of sub-regs that were used. the 3rd is only really maybe needed if 
    #mtr is a Repeat.
    #bt_match returns nil if no initial match could be found.
    
    #if the initial match is unsatisfactory, you should call #backtrack to get another
    #potential match
    
    def bt_match(mtr=matcher,match_steps=mtr.max_matches)
      mtr ||=matcher
      assert cursor.pos <= cursor.size
      assert origpos >= 0
      assert posinc >= 0
      assert( (0..match_steps)===regsidx)
      assert Integer===position_stack.first
      assert check_result
      loop do #loop over regs to match
        assert cursor.pos <= cursor.size
        assert posinc >= 0
        assert( (0..match_steps)===regsidx  || !(mtr.enough_matches? regsidx,cursor.eof?))

        if trace_enabled?
          puts [cursor.pos, regsidx, mtr, clean_result].map{|i|  i.inspect  }.join(' ')
          #pp self
        end
  
        assert check_result

        #try a new match of current reg
        r=mtr.regs(regsidx)
        if r.respond_to? :mmatch and not Formula===r 
        #but what about RegThat? should test for being a Reg::Reg instead
if defined? $MMATCH_PROGRESS 
              m=r.mmatch(self)
#              p r.class
#              p r.__id__
else
              # 'mmatch could return 2 items here'
              m=r.mmatch(cursor.data, cursor.pos)
end
              
              assert check_result
              
              assert ::Array===m || MatchSet===m || !m
              
              #is a single match or a match set?
              if m.respond_to? :next_match
                #it's a set -- start new inner result array
                #with initial match as first elem
                push_matchset m
                mat,matchlen=m.next_match(cursor.data,  cursor.pos)
                
                assert mat
                assert m
              else
#if defined? $MMATCH_PROGRESS 
#                matchlen=m
#else
                mat,matchlen=*m #single match or nil
#end
                m=nil
              end
        else
          if !cursor.eof? and r===(item=cursor.readahead1)
            mat=RR[item]
            matchlen=1
          end
        end
        
        
        assert check_result

        if matchlen   #match succeeded
          if !m and mtr.respond_to? :want_gratuitous_btstop? and \
            mtr.want_gratuitous_btstop?(regsidx)
                push_matchset SingleMatch_MatchSet.new
          end

          #advance to next reg
          assert check_result
          push_match mtr.update_di(0,matchlen)
          assert(cursor.pos<=cursor.size)
        else #match fail?
          assert check_result
          return to_result,posinc,regsidx if mtr.enough_matches? regsidx,cursor.eof?

          #doesn't match, try backtracking
          assert regsidx
          backtrack or return nil #bt failed? we fail
          assert(cursor.pos<=cursor.size)
          assert check_result
          assert(!(mtr.enough_matches? regsidx,cursor.eof?))
        end

        assert(cursor.pos<=cursor.size)

        assert check_result
        assert matchlen || !(mtr.enough_matches? regsidx,cursor.eof?)
        return to_result,posinc,regsidx if regsidx>=match_steps and mtr.enough_matches? regsidx,cursor.eof?
        assert( (0..match_steps)===regsidx  || !(mtr.enough_matches? regsidx,cursor.eof?))

      end #loop

    end

    #---------------------------------------------
    #maybe this isn't necessary?
    #because backtrack is called after it,
    #and it's doing the same things.... more or less
    #used in RepeatMatchSet#next_match and SubseqMatchSet#next_match
    #this method appears to be changing things that it shouldn't?!
    def last_next_match(ctx=context)
      assert check_result
      assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
      assert(ctx.position_inc_stack.size >= 1)
      r=backup_stacks(ctx)  #need to back up the context, not progress (at least sometimes)
     
      di=cursor.pos=ctx.position_stack.last
      assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
      unless r 
        matchfail_todo.push MatchFailRec.new
        assert check_result
        return nil,nil,regsidx
      end
      ctx.position_inc_stack.push 0   #i'm really unsure about this line

      #matchset_stack.pop  is called in backtrack but not here, why?


      r2,diinc=r.next_match(ctx.cursor.data,ctx.cursor.pos)
      matchset_stack.push r
      r=r2
      unless r
        #might need to return non-nil here, if resfrag isn't exhausted yet
        assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
        matchset_stack.pop
        assert check_result
        #huh #oops, should I really be using ctx here?
        return nil,nil,ctx.regsidx unless ctx.matcher.enough_matches? ctx.regsidx,ctx.cursor.eof?
        return to_result, ctx.cursor.pos-ctx.position_stack.first, ctx.regsidx
      end

      assert diinc
      assert ctx.cursor.pos+diinc <= ctx.cursor.size
      ctx.cursor.move diinc
      #regsidx-=matchfail_todo.position_inc #should be done in push_match...
      matchfail_todo.push MatchFailRec.new
      ctx.position_inc_stack.push 0   #i'm really unsure about this line
      ctx.push_match  #need to affect ctx instead of self?
      
      assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
      if ctx.regsidx<ctx.matcher.max_matches  #if there are more subregs of this reg to be matched
        #re-match tail regs
        assert ctx.cursor.pos <= ctx.cursor.size
        #di is sometimes bad here, it seems....(fixed now?)
        assert check_result
        assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
        huh #need to re-start matching where previous bt_match left off
        huh #should bt_match below be looking at ctx instead of self?
        result=bt_match
        assert check_result
        return result
      end



      assert( (0..ctx.matcher.max_matches)===ctx.regsidx)
      assert check_result
      
      return to_result,posinc,ctx.regsidx
    end

=begin
    #---------------------------------------------
    def check_result;
  
if defined? $not_right_now #failing now, dunno why, maybe re-enable later
      #since this should be true, a separate regsidx is unnecessary
      ri=0
      current=self
      begin
        ri+=current.regsidx
      end while current=current.parent
      assert ri==position_stack.size-1
  
      #matchset_stack should be 1 smaller than matchfail_todo
      matchsets=0
      current=self
      begin
        matchsets+=current.matchset_stack.size
      end while current=current.parent
      assert matchfail_todo.size-1==matchsets
end  
  
      #verify correct types in @-variables
      assert ::Sequence===cursor
      assert matcher.respond_to?( :update_di)
      assert regsidx >=0
      matchset_stack.each{|ms| assert MatchSet===ms  }
      prev_pos=0
      position_stack.each{|pos| assert prev_pos<=pos; pos=prev_pos }
      assert prev_pos<=cursor.size 
      
      vars_copy=@variables.dup
      @undos_stack.each {|i|
        case i
        #every element of @variables should also be a sym in @undos_stack
          when Symbol,String: 
            vars_copy.delete(i) or assert(false)
            
          when Later,::Proc:
          else assert(false)
        end
      }
      assert vars_copy.empty?   #every var should be accounted for
  
      #sum of :undos_inc,:matchsucceed_inc,:position_inc in matchfail_todo
      #should be the same as the size of the corresponding stack.
      uns=mats=poss=0
      matchfail_todo.each{|mfr|
        uns+=mfr.undos_inc
        mats+=mfr.matchsucceed_inc
#        poss+=mfr.position_inc
      }
      assert uns==@undos_stack.size
      assert              mats==@matchsucceed_stack.size
 #      assert             poss+1==position_stack.size
     
      assert succ_stack_ok
    
      return true
    end
    
    #---------------------------------------------
    def succ_stack_ok(stk=@matchsucceed_stack)
      stk.each{|elem|
        case elem
          when Array: succ_stack_ok(elem)
          when Later: true
          else
        end or return
      }
      return true
    end
    private :succ_stack_ok
=end  
    #---------------------------------------------
    def clean_result
      result=[]
    #  ms_pos_idx=position_stack.size - matchfail_todo.last.position_inc
      ms_pos_idx=-1
      result=(0...position_stack.size-1).map{|i| 
#        if i==ms_pos_idx
#          ms_pos_idx-=1
#          #what if ms_idx too big?
#          ms_pos_idx-=matchfail_todo[ms_idx].position_inc
#          ms.clean_result

#        else
            cursor[position_stack[i], position_stack[i+1]-position_stack[i]] 
#        end
      }
    
      return result
    end
  
    #---------------------------------------------
    def to_result;
      true#ok, i'm cheating
    end

  end #class Progress



if defined? $MMATCH_PROGRESS  #ultimately, mmatch will take a progress, but until then, disable this
  #---------------------------------------------
  class Array
    def mmatch_full(progress)
      other=progress.cursor.readahead1
      ::Array===other or return false #need to be more generous eventually
      
      progress.newcontext(self, other.to_sequence)
      assert progress.regsidx==0
      result,di,bogus=progress.bt_match
      assert di.nil? || di <= other.size
      progress.endcontext
      #should be returning a matchset here sometimes
      return(di==other.size && result && [true,1])
    end
  end




  #---------------------------------------------
  class Subseq
    
    def mmatch(pr)
    #in this version, all @regs are not multiple regs
      pr.newcontext(self)
      cu=pr.cursor
      start=cu.pos
      assert cu.pos<=cu.size
      cu.pos+@regs.size<=cu.size or return nil
      buf= cu.readahead @regs.size
      @regs.each_with_index do |reg,i|
        assert cu.pos<cu.size
        reg===buf[i] or return nil
      end
      return [true, @regs.size]
    ensure
      pr.endcontext
    end
    
  private
    def mmatch_full(pr)
    #in this version, at least one of @regs is a multiple reg
      orig_stack_size=pr.matchset_stack.size
      pr.newcontext(self)
      cu=pr.cursor
      start=cu.pos
      start+itemrange.begin<=cu.size or return result=nil
      assert( (0..cu.size).include?( start))
      assert pr.regsidx==0
      result,di,bogus=pr.bt_match
      return (result &&= SubseqMatchSet.new(pr,di,orig_stack_size))
    ensure
      assert MatchSet===result || pr.matchset_stack.size==orig_stack_size
      pr.cursor.pos=start
      assert start==pr.cursor.pos
      pr.endcontext      
    end
   end

  #---------------------------------------------
  class Repeat
    include CausesBacktracking
    def mmatch(pr)
      assert pr.check_result
      pr.newcontext(self)
      cu=pr.cursor
      start=cu.pos
      start+@times.begin <= cu.size or return nil  #enough room left in input?
      i=-1
      (0...@times.end).each do |i2| i=i2
        start+i<cu.size or break(i-=1)
        @reg===cu.read1 or break(i-=1)
      end
      i+=1
      assert(   (0..@times.end)===i)
      assert pr.check_result
      cu.pos=start
      if i==@times.begin
        return  [true,i]
      end
      i>@times.begin or return nil
      return SingleRepeatMatchSet.new(pr,i,-1,@times.begin)
    ensure
      pr.endcontext      
    end
    
  private
    def mmatch_full(pr)
      pr.newcontext(self)
      cu=pr.cursor
      orig_stack_size=pr.matchset_stack.size
      start=cu.pos
      assert start <= cu.size
      start+itemrange.begin <= cu.size or return result=nil  #enough room left in input?
      r=[[]]

      #first match the minimum number
      if @times.begin==0 #if we can match nothing
        cu.eof? and return result=[true,0] #at end of input? return empty set
        ri=di=0
      else
        cu.eof? and return result=nil
        assert @times.begin<Infinity
        assert pr.regsidx==0
        r,di,ri=pr.bt_match(nil,@times.begin)  #matches @reg @times.begin times
        r.nil? and return result=nil
      end
      assert ri==@times.begin

      assert !@times.exclude_end?
      left=@times.end-@times.begin

      #note: left and top could be infinite here...

      #do the optional match iterations
      #only greedy matching implemented for now
      #there must be a more efficient algorithm...
      if left >= 1
        #need to re-start matching where previous bt_match left off
        assert pr.check_result
        #get remaining matches up to @times.end times
        assert rr=pr.make_hash
        assert pr.regsidx==@times.begin
        res,di,ri=pr.bt_match   #bt stop at each iteration, this time
        assert pr.check_result
        assert @times===pr.regsidx
        
        res and return result=RepeatMatchSet.new(pr,di, orig_stack_size)
        assert rr==pr.make_hash
      end

      #if matchset has no backtracking stops, and 
      #hence cannot contain more than one actual match,
      #then just return that match.
      return result=if pr.matchset_stack.size==orig_stack_size then 
                      [true,di] 
                    else 
                      RepeatMatchSet.new(pr,di,orig_stack_size) 
                    end
    ensure
      assert MatchSet===result || pr.matchset_stack.size==orig_stack_size
      pr.cursor.pos=start  #is it really this simple? I'm doubtful....
      assert pr.cursor.pos==start      
      pr.endcontext      
    end
  end    
  
  

  #---------------------------------------------
  class And
    include CausesBacktracking
  private
    #can't use this until mmatch interface is changed to take a single progress param
    def mmatch_full(progress)
        #in this version, at least one of @regs is a multiple reg
      progress.newcontext(self)
      assert( (0..progress.cursor.size).include?( progress.cursor.pos))
      assert progress.regsidx==0
      result,di,bogus=progress.bt_match
      
      #uh-oh, di is always 0 here, because And#update_di never does anything.
      #need to come up with some other way to figure out how many items were consumed.
      
      result and AndMatchSet.new(progress,di)
      #need new definition of AndMatchSet...
      
      #need to keep track of which alternative(s) was longest, so as to advance
      #the cursor by that amount. and know which ones to start backtracking in.
      
      #cursor needs to be advanced here somewhere, i think....no
    ensure
      progress.endcontext
    end

  end

  #--------------------------
  class SingleRepeatMatchSet < MatchSet
    def initialize(progress,startcnt,stepper,endcnt)
      endcnt==startcnt and raise 'why even make it a set, then?'
      (endcnt-startcnt)*stepper>0 or raise "tried to make null match set"
      assert startcnt>=0
      assert endcnt>=0
      @progress,@matchtimes,@stepper,@endcnt=progress,startcnt,stepper,endcnt
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
  end

  #--------------------------
  class OrMatchSet < MatchSet
    def initialize(progress,orreg,idx,set,firstmatchlen)
      @orreg,@idx,@set,@firstmatch,@progress=orreg,idx,set,firstmatchlen,progress
      assert ::Array===@firstmatch
#      assert @firstmatch.nil? || Integer===@firstmatch
    end

    def next_match(ary,idx)
      if @firstmatch
        result,@firstmatch=@firstmatch,nil
        assert ::Array===result
#        assert ::Array===result.first.first
        assert 2==result.size
        assert Integer===result.last
        return result
      end
      @set and result= @set.next_match(ary,idx)
      while result.nil?
        @idx+=1
        @idx >= @orreg.regs.size and return nil
        x=@orreg.regs[@idx].mmatch(@progress) #hard spot
        result=case x
          when MatchSet; @set=x;x.next_match
          when Integer; @progress.cursor.readahead( x)
        end
      end
      a=RR[nil]*@orreg.regs.size
      a[idx]=result[0]
      result[0]=a
      assert ::Array===result.first.first
      return result
    end  
  end
  
  #--------------------------
  class Or
    include CausesBacktracking
    def mmatch(pr)
#      assert start <= arr.size
      cu=pr.cursor
      cu.eof? and return nil
      item=cu.readahead1
      @regs.each_with_index {|reg,i|
        reg===item and
          return OrMatchSet.new(pr,self,i,nil,1)
      }
      return nil
    end

  private
    def mmatch_full(pr)
      pr.newcontext(self)
      mat=nil
      assert pos=pr.cursor.pos
      @regs.each_with_index{|r,i|
        if r.respond_to? :mmatch
          assert pr.cursor.pos==pos
          mat=r.mmatch(pr) or next
          if mat.respond_to? :next_match
            huh #is calling next_match bad because it advances cursor?
            len=mat.next_match(pr.cursor.all_data,pr.cursor.pos).last
            return OrMatchSet.new(pr,self,i,mat,len)
          else
            return OrMatchSet.new(pr,self,i,nil,mat)
          end
        else
          item=pr.cursor.readahead1
          r===item and
            return OrMatchSet.new(pr,self,i,nil,[true,1])
        end
      }

      assert mat.nil?
      return nil
    ensure
      pr.endcontext
    end
  end
  
  #--------------------------
  class Xor
    private
    def mmatch_full pr
      pr.newcontext self
      found=nil
      pos=pr.cursor.pos
      @regs.each{|reg|
        assert pr.cursor.pos==pos
        if m=reg.mmatch(pr)
          return if found
          found=m
        end
      }
      return found
    ensure
      pr.endcontext
    end
  end
  
  
  #--------------------------
  class ManyClass
    def mmatch(pr)
      left=pr.cursor.restsize
      beg=@times.begin
      if beg==left ; [true,left]
      elsif beg<left
        make_ms([left,@times.end].min,beg,pr)
      end
    end
    def make_ms(left,beg,pr)
        SingleRepeatMatchSet.new(pr,left, -1, beg)    
    end
  end
    
    class ManyLazyClass
    def mmatch(pr)
      left=pr.cursor.restsize
      beg=@times.begin
      if beg==left ; [true,left]
      elsif beg<left
        make_ms([left,@times.end].min,beg,pr)
      end
    end
      def make_ms(left,beg,pr)
        SingleRepeatMatchSet.new(pr,beg,1,left)
      end
    end
  
  module Reg
    #mmatch implementation for all scalar expressions
    #which don't have an mmatch of their own
    def mmatch(pr)
      !pr.cursor.eof? and self===pr.cursor.readahead1 and [true,1]
    end
  end

 #--------------------------
  class RepeatMatchSet < MatchSet
  
    attr :progress
    def initialize(progress,consumed,orig_stack_size)
      @orig_stack_size=orig_stack_size 
      @progress=progress
      #@cnt=@startcnt-stepper
      #@ary.push 1
      @context=@progress.context
      @consumed=consumed
      @firstmatch=[progress.clean_result,@consumed]
      assert( progress.matcher.times===progress.regsidx)
      assert progress.regsidx
      assert @consumed>=0
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
#        assert result.first.empty? || ::Array===result.first.first
        #print "idx=#{idx}, inc=#{result.last}, arr.size=#{arr.size}\n"
#        assert idx+result.last<=arr.size
#        assert(progress.regsidx==result.first.size) 
        return result
      end
      
      
      @progress or return #not in twin ... ignore it
      
      assert @orig_stack_size <= @progress.matchset_stack.size
      
      @orig_stack_size==@progress.matchset_stack.size and return @progress=nil
      
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
      #but why would i  be 1?    
      if @context.regsidx>@context.matcher.times.begin  #&& i>1
        oldpos=@context.position_stack.last
        progress.backup_stacks(@context) or raise
   #     huh #need to change progress.cursor.pos here too?
        #result of backup_stacks is abandoned, leaked, orphaned
        #we don't want it anymore
        #but what if it's nil?
        
        #but now i need to undo all other progress state too, if 
        #the state was created with the match result just popped.
        #in general, it's not possible to distinguish state with the 
        #last match from state with the matches that might have preceded it...
        #unless I create a backtracking point for each optional iteration
        #of the repeat matcher.
        #currently, making a backtracking point implies making a matchset
        #as well. I'll need a matchset that contains only 1 match.
        #ok, i think this is working now. no extra code needed here.
        
        #recompute # of items @consumed
        @consumed-=oldpos-@context.position_stack.last
        assert @consumed>=0
        #assert(@ri==Backtrace.clean_result(@ary).size)
        assert idx+@consumed<=arr.size
        assert progress.check_result
        result= [progress.clean_result, @consumed]
        assert progress.check_result
        return result
      end


      assert progress.check_result
      assert( (0..@progress.matcher.max_matches)===@progress.regsidx)
      assert(@context.position_inc_stack.size >= 1)
      result,di,ri=progress.last_next_match(@context)
      if result and @progress.matcher.enough_matches? ri,@progress.cursor.eof?
        result=[progress.clean_result,di]
        @consumed=di  #not in twin...why?
        assert @consumed>=0
        #@progress.regsidx-=1
#        assert ::Array===result.first.first
        assert idx+result.last<=arr.size
        assert progress.check_result
        #assert(@ri==result.first.size)
        return result
      end

      assert( (0..@progress.matcher.max_matches)===@progress.regsidx)
      #assert(@ri==Backtrace.clean_result(@ary).size)
      assert(progress.check_result)
      


      @progress.matchset_stack.size==@orig_stack_size and return @progress=nil  #also checking @ary in twin... ignore it
      #  assert @progress.regsidx>0
        
      @progress.backtrack(@context) or return @progress=nil #@progress never set to nil like this in twin... ignore it

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
      assert @consumed>=0
      assert ::Array===result.first.first
      assert idx+result.last<=arr.size
      assert progress.check_result
      #assert(@ri==result.last.size)
      return result
    end

  end

  #---------------------------------------------
  class SubseqMatchSet < MatchSet
    
    def initialize progress,di,orig_stack_size;
      @orig_stack_size= orig_stack_size 
      @progress=progress
      @context=progress.context
      @orig_pos=progress.cursor.pos-di
      @firstresult= [progress.clean_result,di]
    end
 
 #(@reg=>progress.matcher,@matchary=>progress.huh,di=>progress.cursor.pos-@orig_pos)
 
    def next_match(ary,start)
      if @firstresult
        @firstresult,result=nil,@firstresult
        assert ::Array===result#.first.first
        return result
      end

      assert @orig_stack_size<=@progress.matchset_stack.size
      @orig_stack_size==@progress.matchset_stack.size and return @progress=nil
   
      result,di,ri=@progress.last_next_match(@context)
#      result or return @progress=nil      #should this line be here? no
      if result and @progress.matcher.enough_matches? ri,@progress.cursor.eof?
        result=[@progress.clean_result,di]
        return result
      end
      

      #twin has a more sophisticated test on matchset_stack
      (@progress and !@progress.matchset_stack.empty?) or return @progress=nil
      assert @progress.regsidx
      @progress.backtrack(@context) or return @progress=nil

      #need to adjust ri?

      #is this right... dunno...
      # #need to restart where last backtrack left regsidx
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
    #the total number of possible different ways to match an AndMatchSet
    #where several of the branches are actually ambiguous
    #grows exponentially.
    #rather than hit every possible match, we'll try to hit
    #every legal match length at least once.
    
    #on next_match,
    #figure out the alternative(s) that are returning the longest 
    #matchset currently. those alternatives are returned in
    #the first match, but at the 2nd and subsequent calls
    #to next_match, that set of longest alternatives are all
    #next_matched (rolled back) until they match something shorter.
    #(or maybe just a different length? Reg::Or isn't greedy, so its
    #longest match isn't necessarily returned first.)
    
    #if any next_match call returns nil (or false), the whole match set
    #is finished. return nil from next_match now and forever more.
    
    
  
    #def initialize(progress,firstmatchlen)
    #  @progress=progress
    #  @firstmatch=[true,firstmatchlen]
    #  huh
    #end
  
    #this isn't really right...
    #on next_match, we need to backtrack the longest alternative(s)
    #if they're then shorter than the next longest alternative, 
    #then that (formerly next longest) alternative becomes
    #the dominating alternative, and determines how much is consumed
  
  end
  #might need Reg::Or tooo....
  
else #... not $MMATCH_PROGRESS
  class Subseq

    def mmatch(arr,start)
    #in this version, each of @regs is not a multiple reg
      assert start<=arr.size
      start+@regs.size<=arr.size or return nil
      idx=0
      @regs.each { |reg|
        assert(start+idx<arr.size)
        reg===arr[start+idx] or return nil
        idx+=1
      }
      return [true, @regs.size]
    end

    def mmatch_full(arr,start)
      #in this version, at least one of @regs is a multiple reg
      assert( (0..arr.size).include?( start))
      cu=arr.to_sequence cu.pos=start
      pr=Progress.new(self,cu)
      result,di,bogus=pr.bt_match
      result and SubseqMatchSet.new(pr,di)
    end
  end
  
  class Repeat
    def mmatch(arr,start)
      i=-1
      (0...@times.end).each do |i2| i=i2
        start+i<arr.size or break(i-=1)
        @reg===arr[start+i] or break(i-=1)
      end
      i+=1
      assert(   (0..@times.end)===i)
      if i==@times.begin
        return  [true,i]
      end
      i>@times.begin or return nil
      return SingleRepeatMatchSet.new(i,-1,@times.begin)
    end

    def mmatch_full(arr,start)
      assert start <= arr.size
      r=[RR[]]

      cu=arr.to_sequence cu.pos=start
      pr=Progress.new(self,cu)

      #first match the minimum number
      if @times.begin==0 #if we can match nothing
        arr.size==start and return [r,0] #at end of input? return empty set
        ri=di=0
      else
        arr.size==start and return nil
        assert @times.begin<Infinity
        r,di,ri=pr.bt_match(self,@times.begin)  #matches @reg @times.begin times
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
        assert pr.check_result
        #get remaining matches up to @times.end times
         #because bt_match could change the rr argument, and 
        #we might need to return the original in r below
        res,di,ri=pr.bt_match
#        assert Backtrace.check_result res  #this is correct, for now (i think) 
                                           #don't update to progress version
        assert @times===ri
        
        res and return RepeatMatchSet.new(pr,di)
      end

      #if matchset has no backtracking stops, and 
      #hence cannot contain more than one actual match,
      #then just return that match.
      huh 'this needs to change: matchset_stack is shared with whatever came before' 
      pr.matchset_stack.empty? ? di : RepeatMatchSet.new(pr,di)
    end

  end
  

end # $MMATCH_PROGRESS


 

  class Repeat
    #--------------------------------------------------------
    # "enable backtracking stops at each optional iteration"
    def want_gratuitous_btstop?(steps)
      @times===steps
    end
    
  end


  #---------------------------------------------
  class Array
    def ===(other)
      ::Array===other or return false #need to be more generous eventually
      progress=Progress.new(self,other.to_sequence)
      assert progress.regsidx==0
      result,di,bogus=progress.bt_match
      assert di.nil? || di <= other.size
      return(di==other.size && result)
    end
  end

end

if false  #work-around warnings in cursor
warn "warning: ugly workaround for chatty sequence warnings"
propNiller=proc do 
    old_init=instance_method :initialize
    
    define_method :initialize do|*args|
      @positions||=nil;@prop||=nil    
      old_init.bind(self)[*args]
    end
end
::Sequence::Indexed.instance_eval( &propNiller)
::Sequence::Position.instance_eval( &propNiller)
end
