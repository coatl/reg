require 'sequence/singleitem'
require 'thread'
require 'warning'

$EnableSlicings=nil

$bt_catch_method=:bt_stop
#$bt_catch_method=:catch
warning "not sure what $bt_catch_method should be set to"


module Reg
  #--------------------------------------------------------------
  module Reg
    def cmatch_jit_compiler progress
      gen_cmatch
      cmatch(progress) {yield}
    end
    alias cmatch cmatch_jit_compiler
  
    def bmatch_jit_compiler progress
      gen_bmatch
      bmatch progress
    end
    alias bmatch bmatch_jit_compiler
  
    @@injects=0
    def gen_cmatch
      inject_code [
        "undef cmatch ##{@@injects+=1}\n",
        "def cmatch(progress) ##{self.inspect}\n",
        make_new_cursor && [
          $EnableSlicings && [
            "outer_attempt=progress.match_attempt_starting(self)\n",
            "progress.on_throw(:RegMatchFail,  [:match_attempt_fail, outer_attempt])\n"
          ],
          "progress.startcontext(self,(#{make_new_cursor} rescue progress.throw))\n", 
        ],
        "cu=progress.cursor\n",
        $EnableSlicings && ["attempt=progress.match_attempt_starting(self)\n",
           "progress.on_throw(:RegMatchFail, [:match_attempt_fail, attempt])\n"
        ],
        generate_cmatch.to_s.gsub( 
           /\byield\b/, [
             $EnableSlicings && "progress.match_attempt_success(attempt,:subitemrange)\n",      
             make_new_cursor && "progress.endcontext\n",
             $EnableSlicings && make_new_cursor && "progress.match_attempt_success(outer_attempt)\n",
             "yield\n"
           ].to_s
        ),
        "end\n"
      ].to_s.gsub(/^\s*\n/m, '').gsub(/^\s*/, "    ").gsub(/^\s*(un)?def\s/, "  \\1def ")
    end

    def gen_bmatch
      inject_code <<-"END".gsub(/^\s*\n/m, '').gsub(/^\s*/, "    ")
  undef bmatch ##{@@injects+=1}
  def bmatch(progress) ##{self.inspect}
    #{"outer_attempt=progress.match_attempt_starting(self)" if make_new_cursor and $EnableSlicings}
    #{"if (progress.newcontext(self,#{make_new_cursor}) rescue false)" if make_new_cursor}
    cu=progress.cursor
    #{"attempt=progress.match_attempt_starting(self)" if $EnableSlicings}
    result= begin #hmm.. maybe rename that var
    #{generate_bmatch}
    end
    #{post_match}
    #{"result ? progress.match_attempt_success(attempt,:subitemrange) :    progress.match_attempt_fail(attempt)" if $EnableSlicings}
    #{"end" if make_new_cursor}
    #{"
      if result : progress.match_attempt_success(outer_attempt) 
      else   progress.move(-1); progress.match_attempt_fail(outer_attempt)
      end
    " if make_new_cursor and $EnableSlicings}
    
    result
  end
  END
    end
    
    def generate_bmatch
      "    cu.skip(self)\n"
    end
    
    def generate_cmatch
      "    cu.skip(self) or progress.throw\n"+
                "    yield\n"
    end
    
    def make_new_cursor; end
    def throw_guard; end
    def post_match; end

    if (defined? DEBUGGER__) || (defined? Debugger) #and $Debug
      require 'tempfile'
      warning "using weird hack to enable stepping in bmatch/cmatch"

      def inject_code(str)
        tf=Tempfile.new("regmatchcode.#{Thread.__id__}.#{@@injects}_")
        Thread.current[:$reg_matcher]=self
        tf.write "class <<Thread.current[:$reg_matcher]\n"
        tf.write str
        tf.write "end\n"
        tf.flush
        tf.rewind
        load tf.path
        tf.close
      end
    else
      def inject_code(code)
        instance_eval code
      rescue SyntaxError
        print code
        raise
      end
    end
    
    $RegSlicingEnable=nil #leave this off for now
    
    def gen_start_slicing_code i,andword=''
      return '' unless $Debug and $RegSlicingEnable
      sltype=Slicing.for(@regs[i])
      case sltype
      when Slicing::Subseq: pre="sl="
      when nil: sltype="nil"
      else sltype=sltype.name.sub(/^Reg::/,'')
      end 
      construct=".new(@regs_#{i})" unless sltype=="nil"
      return    ["progress.start_slicing(",pre,sltype,construct,",",i,") ",andword," \n"].to_s
    end

    def gen_finish_slicing_code i,andword=''
      return '' unless $Debug and $RegSlicingEnable
      sltype=Slicing.for(@regs[i])
      Slicing::Subseq===sltype or return ''
      "progress.finish_slicing(sl) #{andword} \n"
    end
    
    def subitemrange; itemrange end

    #provide a default version of === that calls cmatch?

    def match_method reg
      case reg
      when HasBmatch: "b"
      when HasCmatch: "c"
      else ""
      end
    end
    
    def bp(condition=OB)
      BP.new self,condition
    end
    
    def match(other)
#      return super if is_a? Composite   #yeccch. ruby includes modules in the wrong order
      self===other and Progress.new(huh( 'empty')).huh  #return new empty progress if ===(other)
    end
  end
 
  class Progress

   #---------------------------------------------
    #remove_method :initialize
    def initialize(matcher,cursor)
#      @parent=nil      #eliminate
#      @matcher=matcher #move into Context
#      @regsidx=0       #move into Context
#      @cursor=cursor   #move into Context
#      @context_stack=[]

       #context_stack is declasse. need @path and @oldpaths instead
      @oldpaths=[]
      @path=Path.new
      assert !cursor.is_a?( ::Sequence::Position )
      newcontext matcher, cursor
#      @matchset_stack=[]
      @matchfail_todo=[MatchFailRec.new]  #list of things to do when match fails.... 
                  #undo(&adjust variables), matchsucceed, position, (matchset)
#      @position_stack=[@cursor.pos] #r-list? of positions
      @variables={}
      @undos_stack=[] # list of undo procs and vars defined in this entire match
      @matchsucceed_stack=[] #things to do when entire match succeeds... subst and deferreds
      
      @child_threads=[]
      warning "need to store root slicing and slicing path somewhere (if slicing enabled)"
      
#      assert check_result
    end
    
#    def cursor; @path.last end
    attr :cursor
    
    def startcontext(matcher,data=@cursor)
      assert !data.is_a?(::Sequence::Position)
      
      @cursor=data
      assert !@cursor.is_a?( ::Sequence::Position )
      @path.push( data, matcher ) rescue (move(-1);throw)
      on_throw(:RegMatchFail,   [:move, -1],:endcontext)
    end
    
    undef newcontext
    def newcontext(matcher,data=@cursor)
      assert !data.is_a?(::Sequence::Position)
      @cursor=data
      assert !@cursor.is_a?( ::Sequence::Position )
      @path.push data, matcher
    end
    
    undef endcontext
    def endcontext
      @path.pop
      @cursor=@path.get_last_cursor
      assert !@cursor.is_a?( ::Sequence::Position )
    end
    
    undef backup_stacks
    def backup_stacks
      assert(matchfail_todo.size >= 1)

      discarding=matchfail_todo.pop

      #backup undo stack and execute undos
      discarding_undos=discarding.undos_inc
      assert @undos_stack.size>=discarding_undos
      process_undos @undos_stack.slice!(-discarding_undos..-1) if discarding_undos>0

      #backup matchsucceed stack
      discarding_succ=discarding.matchsucceed_inc
      assert @matchsucceed_stack.size>=discarding_succ
      @matchsucceed_stack.slice!(-discarding_succ..-1) if discarding_succ>0

    end
     
    #---------------------------------------------
    def bt_stop
#      push_match #this may have to move out into generated code...
      nowpath=@path.dup
       #does Sequence#dup actually return a Position? that would be bad.
      assert !nowpath.is_a?( ::Sequence::Position )
      assert( (oldsize=@oldpaths.size)>=0 )
      @oldpaths.push nowpath.hibernate!
      matchfail_todo.push MatchFailRec.new
      
      #assert @posstack||=[]
      #assert @posstack.push cursor,cursor.pos
      #assert size=@posstack.size
      
      result=catch{
        yield
      }
      
      #...match failure in yield (or subsequently)
      bt_backup
      assert @oldpaths.size==oldsize
      
      #assert size<=@posstack.size
      #assert @posstack.slice!(size..-1)
      #assert size==@posstack.size
      #assert cursor.pos==@posstack.pop
      #assert cursor.equal? @posstack.pop
      result
    end
    
    #---------------------------------------------
    def bt_backup
      backup_stacks
      
      #revert current slicings path to previous path
      $EnableSlicings and huh
      
      #empty @oldpaths implies there are no backtracking stops...
      @path=@oldpaths.pop or return
      @path.reawaken!
      @cursor=@path.get_last_cursor
      assert !@cursor.is_a?( ::Sequence::Position )
      assert @path.ok
    end
    private :bt_backup

    #---------------------------------------------
    def match_attempt_starting mtr; 
      assert @match_attempts||=[]
      assert @match_attempts<<[cursor,cursor.pos,mtr]
      return( assert @match_attempts.size-1 )
    end
    
    #---------------------------------------------
    def match_attempt_success attempt, itemrange_method=:itemrange; 
      assert attempt<@match_attempts.size
      assert cursor.equal?( @match_attempts[attempt][0] )
      assert @match_attempts[attempt].last.send(itemrange_method)===(cursor.pos - @match_attempts[attempt][1])
      #assert @match_attempts.pop
    end
    
    #---------------------------------------------
    def match_attempt_fail attempt;
      assert attempt<@match_attempts.size
      assert cursor.equal?( @match_attempts[attempt][0] )
      assert cursor.pos == @match_attempts[attempt][1]
      assert @match_attempts.slice!(attempt..-1)
    end

    #---------------------------------------------
    def throw(event=:RegMatchFail,result=nil)
      deleting=nil
      assert @catchers.all?{|ctr| !ctr.nil?}
      @catchers.size.-(1).downto(0){|i|
        @catchers[i].first==event and break deleting=@catchers.slice!(i..-1) 
      } 
      deleting or raise "uncaught throw event: #{event}"
      
      deleting.first.last.reverse_each{|m| send(*m) } #execute methods deferred by on_throw
      deleting.reverse_each{|(aborted_event,onfail,*)| 
#        aborted_event==:RegMatchFail   and  event!=:RegMatchSucceed and     bt_backup
        onfail.each{|m| send(*m) }
      }
      if event==:RegMatchSucceed 
        kill_child_threads
        process_laters
      end
      super(event,result)
    end

    #---------------------------------------------
    def catch(event=:RegMatchFail,*onfail,&block)
      @catchers||=[]
      @catchers.push [event,onfail,block,[]]
      assert @catchers.last
      super(event,&block)
    end

    #---------------------------------------------
    def on_throw(event,*onfail)
      catcher=nil
      @catchers.reverse_each{|catcher| 
        if catcher.first==event 
          catcher.last.push(*onfail) 
          break 
        end
      } and raise ArgumentError
    end
  
    #---------------------------------------------
    attr :child_threads
    
    def kill_child_threads
      @child_threads.each{|thr| thr.kill}
      @child_threads=nil
    end
    
    
  
    class Path
      #a path is basically a stack of ::Sequence::Position
      def initialize(*elems)
        @list=elems.map!{|seq| [seq, seq.pos]}.flatten
        @list[-1]=nil unless @list.empty?
        assert ok
      end
      
      def ok
        return true if @list.empty?
        0.step(@list.size-4,2){|i|
          assert @list[i].is_a?( ::Sequence )
          assert @list[i].position?( @list[i+1] )
        }
          assert @list[-2].is_a?( ::Sequence )
          assert !hibernating?||@list[-2].position?( @list[-1] )
      end
    
      def push(datum,matcher=nil)
        assert ok
        assert !datum.kind_of?( ::Sequence::Position )
        @list[-1]=@list[-2].pos unless @list.empty?
        @list.push datum, nil
        assert ok
        #assert datum.pos==@list.last.pos
        return self
      end
      
      def pop
        assert ok
        result,pos=@list.slice!(-2,2)
        assert pos.nil?  #this fails, but extremely rarely... why?
        return result if @list.empty?
        @list[-2].pos=@list[-1]
        @list[-1]=nil
        assert ok
        return result
      end
      
      def dup
        assert ok
        result=super
        result.instance_variable_set(:@list,@list.dup)
        assert ok
        assert result.ok
        return result
      end
      
      extend Forwardable
      def size; @list.size>>1 end
      
      def get_last_cursor
        result=@list[-2]
        result
      end 
      
      def hibernate!
        assert !hibernating?
        assert ok
        @list[-1]=@list[-2].pos unless @list.empty?
        assert hibernating?
        assert ok
        self
      end
      
      def reawaken!
        assert hibernating?
        assert ok
        return self if @list.empty?
        @list[-2].pos=@list[-1]
        @list[-1]=nil
        assert !hibernating?
        assert ok
        self
      end
      
      def hibernating?
        !@list.empty? and
        !@list.last.nil?
      end

=begin      
      def revert_cursors_from(otherpath)
        i=nil
        0.upto(@list.size){|i|
          huh #not sure if equality defined correctly for xcuror::position
          @list[i]!=otherpath[i] and break
        }
        
        i.upto(@list.size){|j|
          @list[j].data.pos=@list[j].pos
        }
      
        huh
      end
=end      
        #attr :list
      
     
    end
  
  end
  
  #--------------------------------------------------------------
  module Multiple
    undef ===
    def ===(other)
      itemrange===1 or return 
      pr=Progress.new self, ::Sequence::SingleItem[other]
      pr.catch( :RegMatchSucceed ){pr.send($bt_catch_method){
        cmatch(pr) {pr.throw(:RegMatchSucceed, true)}
      }}
    end  
#    undef maybe_multiple
  end
 
  
  #--------------------------------------------------------------
  module Composite
    undef at_construct_time
    def at_construct_time(*args)
      multiple_infection(*args)
      undoable_infection
      b_c_match_infection
      cmatch_and_bound_infection
    end  
    
    undef multiple_infection
    def multiple_infection(*regs)
      regs.empty? and regs=subregs
      unless regs.grep(Undoable).empty? or ::Reg::Hash===self or ::Reg::Object===self
        extend Multiple
      end
      #Reg::Array overrides this to do nothing
      #Multiples in the #subregs of Hash,Object,RestrictHash,Case are prohibited
    end

    undef undoable_infection
    def undoable_infection
      unless subregs.grep(Undoable).empty? or ::Reg::Hash===self or ::Reg::Object===self
        extend Undoable
      end
    end

    def b_c_match_infection
      (is_a?(HasCmatch) || subregs.find{|reg|HasCmatch===reg}) && extend(
#        unless is_a?(Multiple) 
#         class<<self; alias generate_bmatch default_generate_bmatch end 
#             HasBmatch
#       else
          HasCmatch
#        end
      ) or
      subregs.find{|reg|HasBmatch===reg} && extend(HasBmatch)
      assert((not (HasCmatch===self)&(HasBmatch===self))) #can't be both at once
    end
    
    def cmatch_and_bound_infection
      unless subregs.grep(HasCmatch_And_Bound).empty?
        extend HasCmatch_And_Bound, HasCmatch
      end
    end
    
    def match(other)
      itemrange===1 or return      
       #create a new progress with other as toplevel context
      pr=Progress.new self, ::Sequence::SingleItem[other]
        #cmatch and return progress
      pr.catch( :RegMatchSucceed ){pr.send($bt_catch_method){
        cmatch(pr) {pr.throw(:RegMatchSucceed, true)}
      }} and pr
    end
  end
  
  
  
  #--------------------------------------------------------------
  module CompileUtils
 
    #explode @regs into @regs_0..@regs_#{@regs.size-1}
    def explode_regs(regs=@regs)
        instance_eval((0...regs.size).map{|i|
          "@regs_#{i}"
        }.join(',')+"=*regs\n") unless regs.empty?
    end
  end
  #--------------------------------------------------------------
    #these are the default forwarding definitions of bmatch and cmatch
    #they forward to each other, so at least one of these methods must be overridden!
  WrapBmatch=proc do
    define_method :generate_bmatch do#forward to cmatch
      #ensure that we aren't using the default version of both match methods, 
      #which results in disastrous infinite mutual recursion
    @_generated_default_match||="b"
    @_generated_default_match!="b" and raise NoMethodError
    <<-END
    progress.#{$bt_catch_method} do
      cmatch(progress){break true}
    end
    END
    end

    alias_method :default_generate_bmatch, :generate_bmatch
  end

  #--------------------------------------------------------------
  WrapCmatch=proc do
    define_method :generate_cmatch do#forward to bmatch
      #ensure that we aren't using the default version of both match methods, 
      #which results in disastrous infinite mutual recursion
    @_generated_default_match||="c"
    @_generated_default_match!="c" and raise NoMethodError
    <<-END  
    if bmatch progress
      yield
    else
      progress.throw
    end
    END
    end
    
    alias_method :default_generate_cmatch, :generate_cmatch
  end
  
  
  #--------------------------------------------------------------
  module HasCmatch
    include CompileUtils
    
  end
  
  #--------------------------------------------------------------
  module HasBmatch
    #include HasCmatch #we have one, but we don't like to talk about it...
    include CompileUtils
  end

  #--------------------------------------------------------------
  module Composite
    include CompileUtils  #is it really so simple? idunno.....
  end

  #--------------------------------------------------------------
  warning "need to extend all Composite patterns with Has[BC]match in initialize()"
  warning "need to call gen_cmatch and gen_bmatch at right times"
  
  #--------------------------------------------------------------
  class BP
    include Reg,Composite,CompileUtils
    def initialize(reg,condition)
      @reg=reg
      @condition=condition
      super
    end
    
    def generate_cmatch
      [(defined? DEBUGGER__ or defined? Debugger)&&"    Process.kill('INT',0) if  @condition===other\n",
       "    @reg.cmatch(progress) {yield}\n"
      ]
    end
    
    def generate_bmatch
      [(defined? DEBUGGER__ or defined? Debugger)&&"    Process.kill('INT',0) if  @condition===other\n",
       "    @reg.bmatch(progress)\n"
      ]
    end
    
    if defined? DEBUGGER__ or defined? Debugger
      def ===(other)
        Process.kill('INT',0) if @condition===other
        @reg===other
      end
    else
      def ===(other)
        @reg===other
      end
    end
  end
  
  #--------------------------------------------------------------
  class Array
    include Composite
    include CompileUtils    
    instance_eval(&WrapBmatch)
    

    #on_throw(...,[move,-1]) in gen_cmatch undoes that read1 call
    def make_new_cursor; "progress.cursor.read1.to_sequence" end
    def throw_guard; "progress.on_throw(:RegMatchFail, :endcontext)\n" end
    def post_match; "progress.endcontext\n" end

    def generate_cmatch
#      self.is_a? HasBmatch and return super  #cant use return here
      generate_cmatch_simple(@regs,"cu.eof? or progress.throw;\n")
    end
  
    def generate_bmatch
      generate_bmatch_simple(@regs,"cu.eof?\n")
    end
  
    def generate_cmatch_simple(regs=@regs,preyield="")
      begin
        explode_regs(regs)

        braces=0
        generate_matchlines(regs,"or progress.throw") {
            braces+=1
        } + [block_given??yield : nil,
             #"p :arr_subseq_preyield\n",
             "    #{preyield} yield\n",
             "    #{'}'*braces}\n",
            ]
      
      end
    end
    
    def generate_bmatch_simple(regs=@regs,presucceed='')
      begin
        explode_regs(regs)
        
        "origpos=cu.pos\nbegin\n"+
        generate_matchlines(regs){
          raise "no cmatches here!"
        }.to_s.sub(/ and *\n$/m, "\n")+
        presucceed+
        "end or (cu.pos=origpos;nil)\n"
      end
    end
    
    
    def generate_matchlines(regs=@regs,andword="and")
        regs.empty? and return ["true\n"]
        #["p :arr_subseq_begin\n"]+
        (0...regs.size).map{|i|
          gen_start_slicing_code(i,andword) +
          case match_method regs[i]
          when "c"
            yield
            "    @regs_#{i}.cmatch(progress) {\n"
          when "b"
            "    @regs_#{i}.bmatch progress #{andword} \n"
          else
            "    cu.skip @regs_#{i} #{andword} \n"
          end
        }    
    end
    
    undef ===
    def ===(other)
      pr=Progress.new self, ::Sequence::SingleItem[other]
      pr.catch( :RegMatchSucceed ){
      pr.send($bt_catch_method){
      cmatch(pr) {
      pr.throw(:RegMatchSucceed, true)
      }}}
    end
  end  

  

  #--------------------------------------------------------------
  class Subseq
    #remove_method :initialize
    def initialize(*args) #override version in regarray.rb
      super
    end
    
    def make_new_cursor; end
    def throw_guard; end
    def post_match; end

    def at_construct_time(*)
      super
      HasCmatch===self or extend HasBmatch
    end
    
    alias generate_bmatch generate_bmatch_simple 
    alias generate_cmatch generate_cmatch_simple 
  
  end
  
  #--------------------------------------------------------------
  class Repeat
    include CompileUtils

    #remove_method :initialize
    def initialize(reg,times)
      Integer===times and times=times..times
      times.exclude_end? and times=times.begin..times.end-1
      assert times.begin <= times.end
      assert times.begin < Infinity
      assert times.begin >= 0
      assert times.end >= 0
      unless HasBmatch===reg || HasCmatch===reg
        assert reg.itemrange==(1..1)
        @itemrange=times
      end
      @reg,@times=reg,times
      super
    end

    def at_construct_time(*)
      (@times.begin<@times.end) and extend HasCmatch 
      super
      HasCmatch===self or extend(  HasBmatch )
    end
    
    def generate_bmatch
      assert !@times.exclude_end?
      assert @times.begin==@times.end
      @times.begin.zero? and return ["true\n"]
      
      ["origpos=cu.pos\n"] + 
      if @times.begin<=4
        [matchline,"\n"]*@times.begin.-(1) +
        [matchline(' or (cu.pos=origpos;nil)'),"\n"]
      else
        ["#{@times.begin}.times{ ",matchline(' or break(cu.pos=origpos)')," }\n"]      
      end
    end

    def matchline andword="and"
      case(method=match_method @reg)
        when "c": "@reg.cmatch(progress) {"
        when "b": "@reg.bmatch progress #{andword}"
        else      "cu.skip @reg #{andword}"
      end
    end
    
    def generate_cmatch
        ir=@reg.itemrange
        if "b"==match_method(@reg) and !@reg.is_a? Undoable  and ir.begin==ir.end
          assert(@times.begin!=@times.end)
          #fixed iterations
          result=if @times.begin<=2
            [matchline("or progress.throw\n")]*@times.begin
          else
            ["#{@times.begin}.times{ #{matchline("or progress.throw")} }\n"]
          end
          #varying iterations
          case variation=@times.end-@times.begin
          when 0:
          when 1: result+=["progress.bt_stop{\n", matchline("or progress.throw\n"), "yield\n", "}\n", "yield\n"]
          when Infinity: 
            iterline="count=0.upto(Infinity){|i| \n"
          else
            iterline="count=#{variation}.times{|i| \n"
          end
          iterline and \
            result+=
            ["oldpos=cu.pos\n",
            iterline,
            matchline("or break(i)\n"),
            "}.downto(0){|i|\n",
            "cu.pos=oldpos+i#{"*#{ir.begin}" unless ir.begin==1}\n",
            "progress.bt_stop{\n",
            "yield\n",
            "}\n",
            "}\n"
            ]
          return result
          
        end
    
        @rest=rest=@times.end-@times.begin
        #why @rest?
        if rest>10
          rest.respond_to?(:infinite?) && rest.infinite? or
            count=rest
          recursive_proc=true
          rest=10
        end
        matchcode=matchline
        needs_close_brace= matchcode[-1]==?{
        opener,closer=[count&&<<END0 ,<<END1],[<<END2]
    (opt_matches+=1)>#{count} and progress.throw :RegRepeatEnd
END0
    progress.bt_stop{
    #{matchcode}
END1
    #{'}' if needs_close_brace}
    }  
#    progress.bt_backup
    yield 
END2
        optional_iterations= [count&&"    opt_matches=0\n"] +
          opener*rest +
          [recursive_proc ? "    rest2[]\n" : "    yield\n"]  +
          closer*rest
        
        [recursive_proc && 
           ["    rest2=proc{\n", 
            count&&"    progress.catch(:RegRepeatEnd){\n",
            optional_iterations, 
            count&&"    }\n",
            "    }\n"],
         [ [matchline('or progress.throw')+"\n"]*@times.begin,
           recursive_proc ? "    rest2[]\n" : optional_iterations, 
           "     #{needs_close_brace ? "}"*@times.begin : "progress.throw" }\n"
         ]
        ]
      end
    end
  
  #--------------------------------------------------------------
  class ManyClass
    #remove_method :initialize
    def initialize(times=0..Infinity)
      Integer===times and times=times..times
      @times=times
      extend @times.begin==@times.end ? HasBmatch : HasCmatch
    end
    def generate_cmatch
      if @times.begin==@times.end
        return "#{@times.begin}==cu.move(#{@times.begin}) or progress.throw\nyield\n"
      end
      code=@times.begin.zero? ? "" : "cu.rest_size>=#{@times.begin} or progress.throw\n"
      code+=
             if @times.end==Infinity
               "cu.rest_size"
             else  
               "[#{@times.end},cu.rest_size].min"
             end +".downto(#{@times.begin}){|i|\n"
      code+=<<-END
      progress.bt_stop{

        cu.move(i)
        yield        
      }
#      progress.bt_backup
    }
    progress.throw
      END
    end

    def generate_bmatch
      assert @times.begin==@times.end
               return "#{@times.begin}==cu.move(#{@times.begin})\n"
    end
  end
    
    #--------------------------------------------------------------
    class ManyLazyClass
      include HasCmatch
      #remove_method :initialize
      def initialize(times=0..Infinity)
        Integer===times and times=times..times
        @times=times
        extend @times.begin==@times.end ? HasBmatch : HasCmatch
      end
      def generate_cmatch
        if @times.begin==@times.end
          return "#{@times.begin}==cu.move(#{@times.begin}) or progress.throw\nyield\n"
        end
        code=@times.begin.zero? ? "" : "    cu.rest_size>=#{@times.begin} or progress.throw\n"
        code+="    #{@times.begin}.upto("
        code+=if @times.end==Infinity
                 "cu.rest_size"
               else  
                 "[#{@times.end},cu.rest_size].min"
               end +"){|i|\n"
        code+=<<-END
      progress.bt_stop{
        cu.move i
        yield        
      }
#      progress.bt_backup
    }
    progress.throw
        END
      end
      def generate_bmatch
        assert @times.begin==@times.end
               return "#{@times.begin}==cu.move(#{@times.begin})\n"
      end
    end
  #--------------------------------------------------------------
  class Or
    include HasCmatch
    def generate_cmatch
      explode_regs
      "    i=0\n"+ 
      (0...@regs.size).map{|i|
        "    progress.bt_stop{\n"+
        case match_method @regs[i]
        when "c":        "    @regs_#{i}.cmatch(progress) {yield}\n"
        when "b":        "    cu.holding?{@regs_#{i}.bmatch(progress)} or progress.throw\n    yield\n"
        else             "    cu.skip(@regs_#{i}) or progress.throw\n    yield\n"
        end+
        "    }\n#    progress.bt_backup\n"
      }.to_s+
      "    progress.throw\n"
    end
  end
  
  #--------------------------------------------------------------
  class Xor
    #the alternatives of xor should be converted to an array of procs
    #so that I can jump about in it at will.
  
    def xortail(h,progress,failevent)
      (h...@regs.size).each{|j|
        progress.send($bt_catch_method){
        @regs[j].cmatch(progress) {
        progress.throw failevent #fail whole xor matcher
        }
        }
      }
    end

    CALLCOUNT="a"
    def cmatch_lines(r,onsuccess="yield")
    CALLCOUNT.succ!
    ["
    origpos=cu.pos
    failevent='RegXorFail_#{CALLCOUNT}'
    progress.catch(failevent) {
    "] + 
    r.map do|i| 
    <<-"END"
    progress.#{$bt_catch_method}{
    @regs_#{i}.cmatch(progress) {
    finalpos=cu.pos
    cu.pos=origpos #reset position after successful xor branch,
    #{"xortail(#{i+1},progress,failevent);" unless i+1==@regs.size}
    cu.pos=finalpos #re-consume matching one if the whole xor succeeds.
    #{onsuccess}
    }
    }
    END
    end+["\n}\n"]
    end

    def generate_cmatch
    explode_regs
    cmatch_lines(0...@regs.size) + 
      "\nprogress.throw\n"
    end
    
    def generate_bmatch
    explode_regs
    cmatch_lines(0...@regs.size,"progress.throw(failevent,true)")
    end
  end
  
  #--------------------------------------------------------------
  class LookAhead
    include CompileUtils
    def at_construct_time(*)
      super
      is_a?(HasCmatch) or extend HasBmatch
    end

    def generate_cmatch
    @code ||= <<-END
    origpos=cu.pos
    @reg.cmatch(progress) {
    cu.pos=origpos
    yield
    }
    END
    end
    
    def generate_bmatch
      huh
    end
  end
  
  
  #--------------------------------------------------------------
  class LookBack
    include CompileUtils
    def at_construct_time(*)    
      super
      is_a?(HasCmatch) or extend HasBmatch
    end

    def generate_cmatch
      case match_method @reg
      when "b","c": 
      movecmd=@reg.itemrange.last==Infinity ? :begin! : "move(0-[#{@reg.itemrange.last},cu.pos].min)"
     ["    origpos=cu.pos",
      "    cu.pos>=#{@reg.itemrange.first} or progress.throw\n",
      "    fudge=cu.#{movecmd}-#{@reg.itemrange.first}\n",
      "    regs_ary(origpos,fudge).-@.cmatch(progress) {yield}\n"] #not inlineable?
      else
      need0poscheck="cu.pos.nonzero?() &&" if @reg===nil
      "    #{need0poscheck} cu.checkback(@reg) or progress.throw\n"+
      "    yield\n"
      end
    end
    
    def generate_bmatch
      case match_method @reg
      when "c": raise "hell"
      when "b": 
      movecmd=@reg.itemrange.last==Infinity ? :begin! : "move(0-[#{@reg.itemrange.last},cu.pos].min)"
     ["    origpos=cu.pos",
      "    if cu.pos>=#{@reg.itemrange.first}\n",
      "    fudge=cu.#{movecmd}-#{@reg.itemrange.first}\n",
      "    regs_ary(origpos,fudge).-@.bmatch(progress)\n",
      "    end\n"] #not inlineable?
      else
      need0poscheck="cu.pos.nonzero?() &&" if @reg===nil
      "    #{need0poscheck} cu.checkback(@reg)\n"
      end
    end
  end
  
  #--------------------------------------------------------------
  class Position
    include HasBmatch

    def generate_bmatch
      if @positions.size>5
        "    @positions.include? adjust_position(progress,cu.pos)\n"
      else
        need_pos=need_rpos=nil
        
        result=@positions.map{|pos|
        if !Position.negative?(pos)
          need_pos=true
          "result= pos==#{pos}"  
        else
          need_rpos=true
          "result= rpos==#{pos.nonzero? || 0}\n"+
          #"p :position_postmatch, result, rpos, #{pos}, cu.pos, cu.size\n"+
          "result"
        end
        }.join(" or \n")+"\n"
        need_pos and result="pos=cu.pos\n"+result
        need_rpos and result="rpos=cu.pos-cu.size\n"+result
        #"p :position_prematch, cu.pos\n"+
        result
      end
    end
  end

  
  #-------------------------------------
  module HasCmatch_And_Bound; end

  #--------------------------------------------------------------
  class Bound
  
    def at_construct_time(*)
      super
      extend(is_a?(HasCmatch) ? HasCmatch_And_Bound : HasBmatch)
    end

    def generate_cmatch
    case match_method @reg
    when "c": 
     ["    origpos=cu.pos\n",
      "    @reg.cmatch(progress) {\n",
      "    progress.register_var(@name,origpos...cu.pos)\n",
      "    yield\n",
      "    }\n"]
    when "b": 
     ["    origpos=cu.pos\n",
      "    if @reg.bmatch progress\n",
      "    progress.register_var(@name,origpos...cu.pos)\n",
      "    yield\n",
      "    end\n",
      "    progress.throw\n"]
    else
     ["    progress.register_var(@name,cu.pos)\n",
      "    if (cu.skip @reg)\n",
      "      yield\n",
      "    else\n",
      "      progress.unregister_var @name\n",
      "      progress.throw\n",
      "    end\n"]
    end
    end

    def generate_bmatch
    case match_method @reg
    when "c": raise "hell"
    when "b": 
     ["    origpos=cu.pos\n",
      "    @reg.bmatch progress and\n",
      "    progress.register_var(@name,origpos...cu.pos)\n"
      ]
    else
     ["    progress.register_var(@name,cu.pos)\n",
      "    (cu.skip @reg) or\n",
      "      progress.unregister_var @name\n"
      ]
    end
    end
  end
  
  #--------------------------------------------------------------
  module BackrefLike
    include HasBmatch
    def self.to_indexed(progress,vec)
      if ::Array==progress.cursor.data_class
        Array(vec)
      else
        vec.to_s
      end
    end
  
    
    
    
    def generate_bmatch
            "    cells=formula_value(huh,progress) and \n"+
      "    cells=::Reg::BackrefLike.to_indexed(progress,cells) and \n"+
      "    cu.skip_literals cells\n"
    end
    instance_eval(&WrapCmatch)
  end
  
  #--------------------------------------------------------------
  module BRLike
    include HasBmatch
  end
    
  #--------------------------------------------------------------
  class Backref
    include HasBmatch
    
    def generate_bmatch
             "    cells=formula_value(huh,progress) and \n"+
      "    cells=::Reg::BackrefLike.to_indexed(progress,cells) and \n"+
      "    cu.skip_literals cells\n"
    end
    instance_eval(&WrapCmatch)
  end

  #--------------------------------------------------------------
  class BR
    include HasBmatch
    
    def generate_bmatch
             "    cells=formula_value(huh,progress) and \n"+
      "    cells=::Reg::BackrefLike.to_indexed(progress,cells) and \n"+
      "    cu.skip_literals cells\n"
     end
    instance_eval(&WrapCmatch)
  end

  
  #--------------------------------------------------------------
  class Transform
    #include HasBmatch
    def generate_cmatch
    case match_method @reg
    when "c": huh
         "    origpos=cu.pos\n"+
         "    @reg.cmatch(progress){\n"+
         "    progress.register_replace(origpos,cu.pos-origpos,@rep)\n"+
         "    yield\n"+
         "    }\n"
         
    else "    (#{generate_bmatch}) or progress.throw\n"+
         "    yield\n"
    
    end
    end
    
    def generate_bmatch
    "    origpos=cu.pos\n"+
    case match_method @reg
    when "c": raise "hell"
    when "b": 
    "    @reg.bmatch(progress) and\n"
    else 
    "    cu.skip @reg and\n"
    end+
    "    progress.register_replace(origpos,cu.pos-origpos,@rep)\n"
    end
  end
  
  #--------------------------------------------------------------
  class Finally
    def at_construct_time(*)
      super
      HasCmatch===self or extend HasBmatch
    end
    
#    include HasBmatch
    def generate_cmatch
    case match_method @reg
    when "c": <<-END
      @reg.cmatch(progress) {
      progress.register_later progress,&@block
      yield
      }
    END
    else <<-END
      if (#{generate_bmatch})
      yield
      else
      progress.throw
      end
    END
    end
    end

    def generate_bmatch 
    case match_method @reg
    when "c": raise "finally match compile error"
    when "b": "@reg.bmatch progress" 
    else      "cu.skip @reg"
    end +" and
      (progress.register_later progress,&@block;true)\n"
    end
  end


  #--------------------------------------------------------------
  class SideEffect
    def generate_bmatch
    
      "if result="+
      if HasBmatch===@reg
        "@reg.bmatch progress"
      else
        "cu.skip @reg"
      end+"\n"+
      "@block.call(progress)\n"+
      "result\n"+
      "end\n"
    end
    
    def generate_cmatch
      if HasCmatch===@reg
        "@reg.cmatch(progress) {@block.call(progress); yield}\n"
      else
        "(#{generate_bmatch}) or progress.throw\n"+
        "yield\n"
      end
    end
  end

  #--------------------------------------------------------------
  class Undo
    def generate_bmatch
      huh
    end
    def generate_cmatch
      huh
    end
  end
  
  #--------------------------------------------------------------
  class Interpret
    def generate_bmatch
      huh
    end
    def generate_cmatch
      huh
    end
  end
  
  #--------------------------------------------------------------
  class ::Set
    include HasBmatch
    
    def generate_bmatch
    @bcode||=
    "   self.include? cu.readahead1 and cu.move(1).nonzero?\n"
    end
  end
  
  #--------------------------------------------------------------
  class Case
    def generate_bmatch
      huh
    end
    def generate_cmatch
      huh
    end  
  end

=begin try to implement Hash/Object
  #--------------------------------------------------------------
  class Hash
    class Literals
      include Reg,Composite,CompileUtils
      def initialize(keys,vals)
        @keys,@regs=keys,Reg::Array.new(*vals)
      end
      
      attr :keys
      
      def subregs
        @keys.map{|key|
          if Reg.interesting_matcher? key
            Equal.new key
          else
            key
          end
        }+[@regs]
      end
      
      def ===(other)
        huh
        
        huh #but I also have to set up GraphPoint::HashValue context??
        return @regs===(other.indexes(*@keys) rescue return)
        
        
          result=true
          @regs.each_with_index{|r,i|
            r===actual[i] or break result=false
          }
          return result
      end
      
      def generate_bmatch
        explode_regs
        huh
        "    other=progress.cursor.readahead1\n"+
        "    if (actual=other.values_at(*@keys) rescue nil)\n"+
        (0...@valmtrs.size).map{|i|
          case match_method @regs[i]
          when "c","b": 
               "    progress.with_context(GraphPoint::HashValue.huh,actual[#{i}]) and \n"
               "    @regs_#{i}.bmatch(progress) and \n"
          else "    @regs_#{i}===actual[#{i}] and \n"
          end
        }+
        "    progress.cursor.move 1\n"+
        "    end\n"
      end
      
      def generate_cmatch
        explode_regs
        braces=0
        huh
        "    other=progress.cursor.readahead1\n"+
        "    if(actual=other.values_at(*@keys) rescue nil)\n"+
        (0...@valmtrs.size).map{|i|
          case match_method @regs[i]
          when "c":
               braces+=1
               "    progress.with_context(GraphPoint::HashValue.huh,actual[#{i}]) and \n"+
               "    @regs_#{i}.cmatch(progress) {\n" 
          when "b": 
               "    progress.with_context(GraphPoint::HashValue.huh,actual[#{i}]) and \n"
               "    @regs_#{i}.bmatch(progress) and \n"
          else "    @regs_#{i}===actual[#{i}] and \n"
          end
        }+
        "    progress.cursor.move(1).nonzero? and yield\n"+
        "    #{%/}/*braces}\n"+
        "    end\n"+
        "    progress.throw\n"
      end
    end
    
    #--------------------------------------------------------------
    class MatcherPair
      include Reg,Composite,CompileUtils
      def initialize(mkey,mval)
        @mkey,@mval=mkey,mval
      
      end
      
      def subregs
        [@mkey,@mval]
      end
      
      def ===(other) 
      raise NoMethodError
      huh
        other.each{|k,v|
          if @mkey===k
            @mval===v or return
          end
        }
        huh #also need to keep track of which keys of other actually matched something, for parent Reg::Hash
      end
      
      def bmatch progress
      huh
        huh progress.with_context(huh,huh)
        
        other=progress.cursor.readahead1
        other.each{|k,v|
          if @mkey===k
            @mval===v or break
            progress.context.seen_keys<<k
          end
        } and
        huh #advance cursor if match success
      end
      
      def cmatch progress
      huh
      
      end
      
      
      huh
    end
    
    #--------------------------------------------------------------
    class CatchAll
      def initialize
        huh
      end
    end
  
  end
=end

=begin another try at Reg::Hash and Object
    warning "Reg::Hash, Reg::Object and friends need to be made possibly Undoable and Multiple again"
    warning "if the compiled implementations of those matchers are to be used"
    warning "take out the Reg::Hash/Object hacks in multiple_infection and undoable_infection"
    #--------------------------------------------------------------
    module Map
     def generate_generic(
       matchmeth=:cmatch,needdo=:do,
       final=nil
     )
      needdo ? final||="{yield}" : needif=:if
      %{
      h=progress.data
      litvals=h.values_at(*@literals_keys)
      h=h.dup     
      huh "maybe need more generic form of h.dup"
      @literals_keys.each{|lit| h.delete lit }
      #{needif} @literals_vals.#{matchmeth}(progress.huh_with_new_data litvals) #{needdo}
        a=h.inject([]){|list,pair| 
          if @literals_keys_set.include? pair.first
            list
          else
            list+pair
          end
        }<<h.default
        def a.matched_counts; @matched_counts end
        a.instance_variable_set(  :@matched_counts, Array.new(huh @matchers.size+1,0)  )
        @array_style.#{matchmeth}(progress.huh_with_new_data a) #{final}
      end
      }
     end
    
    end
    
    #--------------------------------------------------------------
  class Hash

    include Reg,Composite
    include CausesBacktracking #of course, it's not implmented correctly, right now
    include Map
    attr :others
    
    @@eventcount=0
    def initialize(*args)
        @matchers=[]
        @literals=[]
        @others=nil
      if 1==args.size  #unordered list of pairs
        hashdat=args.first or return 
        hashdat.key?(OB) and @others=hashdat.delete(OB) 
        hashdat.each {|key,val| 
          if !Reg.interesting_matcher? key
            Equals===key and key=key.unwrap
            @literals<<[key,val]
          else
            Fixed===key and key=key.unwrap
            @matchers<<[key,val]
          end
        }
      else  #ordered list of pairs
        args.each{|pair|
          key,val=*pair
          consider_literals=true
          if !Reg.interesting_matcher? key and not Undoable===val and consider_literals
            Equals===key and key=key.unwrap
            @literals<<pair
          elsif key==OB
            @others=val
          else
            Fixed===key and key=key.unwrap
            @matchers<<pair
            consider_literals=false
          end
        }
      end
      #transform optional values to their final form
      [@literals,@matchers].each{|list| list.map!{|(k,val)| 
        if Repeat===val 
#          <<-end
          if val.itemrange==(0..1): [k,val.reg|huh(HashDefault.new(k))] #HashDefault not invented yet
          elsif val.itemrange==(1..1): [k,val.subregs.first]
          else raise(TypeError.new( "multiple matcher not expected in hash") )
          end
        else [k,val]
        end
      }}
      
      @literals_keys=@literals.map{|(k,v)| k}
      @literals_vals=+@literals.map{|(k,v)| v}
      
      incproc=proc{|i| proc{|pr| pr.cursor.data.matched_counts[i]+=1}}
      decproc=proc{|i| proc{|pr| pr.cursor.data.matched_counts[i]-=1}}
      all_matchers=@matchers+[OB,@others]
      i=-1
      warning "ordered hash matchers (at least) need to support matcher-by-matcher match attempt order"
      event="fail_hash_matcher#{@@eventcount+=1}"
      @array_style=[ @literals_vals,
                    all_matchers.inject(OB){|conj,(k,v)| i+=1
                      conj&-[
                       [ OBS.l, 
                        k,
                        v.reg.side_effect(&incproc[i]) \
                         .undo(&decproc[i]) \
                         |Reg.event(event)
                       ].-@.*, OBS         
                      ]
                    }.*,
                    item_that{|item,pr| 
                      j=-1
                      pr.cursor.data.matched_counts.all?{|mcount| j+=1
                        mcount.nonzero? or all_matchers[j].last===item
                      }
                    }
                  ].+@.fail_on(event)
                  

      super
      
      
      assert !is_a?(Multiple)  #should be no Multiples in subregs
    end
    
    def ordered; self end

    def subregs;
      lkeys=[];lvals=[]
      @literals.each{|(k,v)| lkeys<<k; lvals<<v}
      mkeys=[];mvals=[]
      @matchers.each{|(k,v)| mkeys<<k; mvals<<v}
      
      lkeys+lvals+mkeys+mvals+
      (@others==nil ? [OB,@others] : [])
    end
    
    def inspect
      warning 'is this right?'
      result=[]
      h=::Hash[*@literals.inject([]){|list,pair| list+pair}]
      result<<h.inspect.sub(/.(.*)./, "\\1") unless @literals.empty?
      h=::Hash[*@matchers.inject([]){|list,pair| list+pair}]
      result<<h.inspect.sub(/.(.*)./, "\\1") unless @matchers.empty?
      result<<"OB=>#{@others.inspect}"  if defined? @others and @others!=nil
      return "+{#{result.join(", ")}}"
    end

    #on_throw(...,[move,-1]) in gen_cmatch undoes that read1 call
    def make_new_cursor; "(
      result=::Sequence::OfHash.new(h=progress.cursor.read1,@literals_keys).
        unshift(h.values_at(@literals_keys))
      def result.matched_counts; @matched_counts end
      result.instance_variable_set(  :@matched_counts, Array.new(huh @matchers.size+1,0)  )
      result
      )" 
    end

    def throw_guard; "progress.on_throw(:RegMatchFail, :endcontext)\n" end
    def post_match; "progress.endcontext\n" end

    remove_method :===
   
    def generate_bmatch
      "@array_style.bmatch(progress)"
    end
    
    def generate_cmatch
      "@array_style.cmatch(progress) {yield}"           
    end
    
if false    
    def ===(other)
      pr=Progress.new self, ::Sequence::SingleItem[other]
      progress.catch( :RegMatchSucceed ){progress.send($bt_catch_method){
      cmatch(pr) {progress.throw(:RegMatchSucceed, true)}
      }}    
      warning "identical with Array#==="  
    end
    
    def literals_val_match_code i, matval, op="and"
        case match_method matval
        when "c": 
        "@literals_val_#{i}.cmatch(progress) {"
        when "b": 
        huh #setup cursor&context
        "@literals_val_#{i}.bmatch progress #{op}\n"
        else huh
        "@literals_val_#{i}===other[@literals_key_#{i}] #{op}\n"
        end    
    end
    
    def matchers_key_match_code j,matkey
        case match_method matkey
        when "c": huh
        when "b": 
        huh #setup cursor&context
        "@matchers_key_#{j}.bmatch progress"
        else huh
        "@matchers_key_#{j}===okey"
        end    
    end
    
    def matchers_val_match_code j,matval
        case match_method matval
        when "c": huh
        when "b":
        huh #setup cursor&context
        "@matchers_val_#{j}.bmatch progress"
        else huh
        "@matchers_val_#{j}===other[okey]"
        end
    end
    
    def catchall_val_match_code
      case match_method @others
      when "c": huh
      when "b": huh
      huh #setup cursor&context
      "@others.bmatch progress"
      else huh
      "@others===other[okey]"
      end
    end
      
    def default_match_code(cmatches_too=nil)
    huh #handle cmatch here too 
      <<-END
             
            default=other.default
            defaultrest=nil
            defaultval||=proc{|unv,idx,&rest|
            case match_method unv
            when "c": huh
            #{!cmatches_too ? "raise 'hell'\n" :
              "defaultrest[idx+1,&rest]\n"
            }
            when "b":
            progress.with_context(GraphPoint::HashDefaultValue)
            unk.bmatch progress
            else unv===default
            end or progress.throw            
            }
            
            defaultrest||=proc{|idx,&rest|
            unseenmatchers[idx..-1].find_all{|(unk,unv)|
            case match_method unk
            when "c": 
            #{!cmatches_too ? "raise 'hell'\n" :
              "defaultval.call unv,idx {}"
              
              
            }
            when "b":
            progress.with_context(GraphPoint::HashDefaultKey)
            unk.bmatch progress
            else
            unk===nil
            end or progress.throw
            
            defaultval.call unv,idx {}
            }
            rest.call
            }
      END
    end

    def generate_cmatch
      warning %#need to generate code that creates a new graphpoint context#
      #and changes that context on every hash key/val
      #also, ::Sequence::SingleItem stuff
      warning %#need calls to progress.with_context here#
      warning "I think it's ok now..."
      i=j=0
      @matchers.each{|(matkey,matval)|
        j+=1
        instance_variable_set("@matchers_key_#{j}",matkey)
        instance_variable_set("@matchers_val_#{j}",matval)
      }
      @unseenmatchers||=Set[*@matchers.map{|(key,v)| key}]
      <<-END+
    okey=nil
    unseenmatchers=@unseenmatchers.dup
    okey=nil
    matchersrest=proc{|idx,&rest|
    (idx...@matchers.size).each{|i|
    matkey,matval=@matchers[i]
      END
      
      huh+ "backtracking in and matchers is a problem"+
      huh+ "some kinda loop needed"+
          "    failevent=%[RegHashFail\#{@_callcount||=0;@_callcount+=1}]\n"+
          "    progress.catch(failevent) {\n"+
          "    progress.#{$bt_catch_method} {\n"+
          "    progress.with_context(GraphPoint::HashKey,okey)\n"+
          "    "+matchers_key_match_code( j,matkey)+" or progress.throw\n"+
          
          "    progress.#{$bt_catch_method} {\n"+
          "    progress.with_context(GraphPoint::HashVal,okey)\n"+
          "    "+matchers_val_match_code( j,matval)+" or progress.throw failevent\n"+
          "    unseenmatchers.delete @matchers_val_#{j}\n"+
          "    rest.call\n"+
          "    }\n"+ #catch :RegMatchFail#2
          "    progress.throw failevent\n"+
          "    }\n"+ #catch :RegMatchFail#1
          "    }\n"+ #catch failevent
          "    progress.throw\n"+
          "    }\n"+ #each
          "    matchersrest.call i+1, &rest\n"+
          "    }\n"+ #proc
          
          
          
          
          huh+
      @literals.to_a.map{|(litkey,matval)|
        i+=1
        instance_variable_set("@literals_key_#{i}",litkey)
        instance_variable_set("@literals_val_#{i}",matval)
        "    progress.with_context(GraphPoint::HashValue,@matchers_key_#{i})\n"+
        "    "+(literals_val_match_code i, matval, "or progress.throw\n")
      }+
      "    (other.keys-@literals.map{|(key,val)| key }).each{|okey|\n"+
      "    matchersrest.call 0 {\n"+  #attempt 
      huh+ #finish unmatched keys, 
    
      huh+ #default processing
      "    progress.with_context(GraphPoint::HashDefault)\n"+
      "    "+catchall_val_match_code(" or progress.throw")+"\n"+
      huh+ 
      (unseenmatchers=unseenmatchers.to_a;'')+
      default_match_code(true)+
      "    yield\n"+
      "    }\n"+
      "    other.empty? and (@others===other.default rescue false) || progress.throw\n"+
      "    yield\n"+
      
      
      huh+ #"    ensure\n    progress.endcontext\n"
       huh+ #"must always endcontext before yield"
       huh #"lotsa end } were omitted"
    end
    
    def generate_bmatch
      huh #need to generate code that creates a new graphpoint context
      #and changes that context on every hash key/val
      #also, ::Sequence::SingleItem stuff
      huh #need calls to progress.with_context here
      @unseenmatchers||=Set[*@matchers.map{|(key,v)| key}]
      
      i=j=0
      "    other=cu.readahead1\n"+
      "    unseenmatchers=@unseenmatchers.dup\n"+
      "    return unless\n"+  huh("cant return in bmatch")+
      
      @literals.to_a.map{|(litkey,matval)|
        i+=1
        instance_variable_set("@literals_key_#{i}",litkey)
        instance_variable_set("@literals_val_#{i}",matval)
        
        "    progress.with_context(GraphPoint::HashValue,@literals_key_#{i}) && \n"+
        "    "+literals_val_match_code(i, matval)
      }.to_s.sub(/ and *\n$/,"\n")+
      "    (other.keys-@literals.keys).each{|okey|\n"+
      @matchers.to_a.map{|(matkey,matval)|
        j+=1
        instance_variable_set("@matchers_key_#{j}",matkey)
        instance_variable_set("@matchers_val_#{j}",matval)
        "    if "+
        "    progress.with_context(GraphPoint::HashKey,@matchers_key_#{j}) && \n"+
        matchers_key_match_code( j,matkey)+"\n"+
        "    return unless "+  huh("cant return in bmatch")+
        "    progress.with_context(GraphPoint::HashValue,@matchers_val_#{j}) && \n"+
        matchers_val_match_code( j,matval)+"\n"+
        "    unseenmatchers.delete @matchers_val_#{j}\n"+
        "    next\n"+
        "    end\n"
      }.to_s+
      huh+ #default processing
      "huh.with_context"+
      "    "+catchall_val_match_code+" or return\n"+  huh("cant return in bmatch")+
      "    }\n"+
      
      huh+ 
      default_match_code+
        "    other.empty? and return (@others===other.default rescue false)\n"+  huh("cant return in bmatch")+
        "    return true\n"+  huh("cant return in bmatch")+

      
      huh+ "    ensure\n    progress.end_context\n"+
        huh+ "advance cursor if match successful"
    end
end    
    
  end

  #--------------------------------------------------------------
  class RestrictHash
    warning "need     'assert(!is_a? Multiple)' in initialize()"

    def generate_bmatch
      huh
    end
    def generate_cmatch
      huh
    end
  end

  #--------------------------------------------------------------
  class Object
    include Map
    def initialize(*args)
      hash= (::Hash===args.last ? args.pop : {})
      
      @vars=[]; @meths=[]; @meth_matchers=[]; @var_matchers=[]
      argmuncher=proc{|(item,val)|
        if ::String===item or ::Symbol===item
          item=item.to_s
          (/^@/===item ? @vars : @meths)<<[item.to_sym,val]
        elsif Regexp===item && item.source[/^\^?@/]
          @var_matchers<<[item,val]
        elsif And===item && Regexp===item.subregs[0] && item.subregs[0].source[/^\^?@/]
          @var_matchers<<[item,val]
        elsif Wrapper===item
          @meth_matchers<<[item.unwrap,val]
        else 
          @meth_matchers<<[item,val]
        end
      }
      args.each( &argmuncher )
      hash.each( &argmuncher )
      @over_ivars=OverIvars.new(*@vars+@var_matchers)
      @over_meths=OverMethods.new(*@meths+@meth_matchers)
      #@meths[:class]=args.shift if (Class===args.first) and args.size%2==1
            
      warning %#need to xform optional elements(using .-) just like in Reg::Hash too#
      super
      assert !is_a?(Multiple)
    end
    
    def generate_bmatch
      "\n@over_ivars.bmatch(progress) && move(-1) && @over_meths.bmatch(progress)\n"
    end
    def generate_cmatch
      "\n@over_ivars.cmatch(progress) { move(-1); @over_meths.cmatch(progress) {yield} }\n"
    end
 
    class OverIvars < Object
     def initialize(*args)
      hash= (::Hash===args.last ? args.pop : {})
      
      @meths=@meth_matchers=[].freeze
      @vars=[]; @var_matchers=[]
      argmuncher=proc{|(item,val)|
        if ::Symbol===item or item.respond_to? :to_str
          item=item.to_str
          /^@/===item or raise ArgumentError
          
          @vars<<[item.to_sym,val]
        else
          @var_matchers<<[item,val]
        end
      }
      args.each( &argmuncher )
      hash.each( &argmuncher )
      
      @literals_keys=@vars.each{|(k,v)| k}
      @literals_vals=@vars.each{|(k,v)| v}
      @matchers=@var_matchers
            
            
      huh_build_@array_style
      
      super()
      assert !is_a?(Multiple)
    end
    def generate_bmatch
      huh generate_generic
    end
    def generate_cmatch
      huh generate_generic
    end
    
    end
    
    class OverMethods < Object
     def initialize(*args)
      hash= (::Hash===args.last ? args.pop : {})
      
       @vars=@var_matchers=[].freeze
      @meths=[]; @meth_matchers=[]
      argmuncher=proc{|(item,val)|
        if  ::Symbol===item or item.respond_to? :to_str
          item=item.to_str
          @meths<<[item.to_sym,val]
        else 
          @meth_matchers<<[item,val]
        end
      }
      args.each( &argmuncher )
      hash.each( &argmuncher )
      
       @literals_keys=@meths.each{|(k,v)| k}
      @literals_vals=@meths.each{|(k,v)| v}
      @matchers=@meth_matchers
 
        huh_build_@array_style
           
      super() 
      assert !is_a?(Multiple)
    end
    def generate_bmatch
      huh generate_generic
    end
    def generate_cmatch
      huh generate_generic
    end
    end


  end
=end
  
  #--------------------------------------------------------------
  class Not
    def generate_bmatch
      case match_method @reg
      when "c": raise "hell"
      when "b": 
           "    cu.holding{ !@reg.bmatch progress }"+
           (" and cu.move(1)" if @reg.itemrange==(1..1)).to_s
      else "    cu.skip self"
      end+"\n"
    end
    
    def generate_cmatch
      case match_method @reg
      when "c": 
           "    progress.catch(:RegNotFail) {\n"+
           "    progress.#{$bt_catch_method} {\n"+
           "    @reg.cmatch(progress) {progress.throw :RegNotFail}\n"+
           "    }\n"+
           "    yield\n"+
           "    }\n    progress.throw\n"
      else "    (#{generate_bmatch}) or progress.throw\n"+
           "    yield\n"
      end
    end
  end

  
  #--------------------------------------------------------------
  class And
          
    class ThreadProgress<Progress
      def initialize(matcher,parent)
        super(matcher,parent.cursor)
        parent.instance_variable_get( :@matchsucceed_stack).push( method( :process_laters ) )
        parent.instance_variable_get( :@undos_stack).push( method( :process_undos ) )
        @thread,@parent=nil,parent
      end
      attr_accessor :thread
      def lookup_var(name)
        super or @parent.lookup_var(name)
      end
      alias [] lookup_var
    end          
      warning "need more and concurrency testing"
      warning %#need to discover dependancies among and alternatives#
      #(ie a variable capture in one alternative being used in a backref
      #in a subsequent alternative.)
      #then use those dependancies to sort @regs so that var cap is always before
      #backref

    instance_eval(&WrapBmatch)
    def generate_cmatch
        return "    yield\n" if @regs.empty?
        warning %#pull out ordinary matchers for processing outside the andmachine and its threads#
        warning "not sure whether to use progress's version of catch/throw here"
        maybe_progress="progress."
        #maybe_progress=nil
        @a_regs=(0...@regs.size).to_a
        @cb_regs,@a_regs=@a_regs.partition{|reg_n| /^[cb]/===match_method(@regs[reg_n])}
        unless @a_regs.empty?
          a_part=<<-A
    x=progress.cursor.readahead1
    progress.throw unless #{
      @a_regs.map{|a| "    @regs[#{a}]===x"}.join(" and \n")
    }
          A
          return a_part+"    progress.cursor.read1\n    yield\n" if @cb_regs.empty?
        end
        @c_regs,@b_regs=@cb_regs.partition{|reg_n| /^c/===match_method(@regs[reg_n])}
        @c_regs=@regs.values_at(*@c_regs)
        @c_regs<<OB unless @c_regs.empty? or @a_regs.empty? #signal to andmachine that >=1 item must always match
#        @b_regs=@regs.values_at(*@b_regs)
        unless @b_regs.empty?
          b_part=<<-B
    cu=progress.cursor
    ends=[]
    pos=cu.pos
    #{@b_regs.map{|n| "
      @regs[#{n}].bmatch(progress) or progress.throw
      ends<<cu.pos
    "}.join("\n      cu.pos=pos\n")}
          B
          return a_part.to_s+b_part+"    cu.pos=ends.max\n    yield\n" if @c_regs.empty?
        end
    return <<-C
    #p :and_cmatch
    #{a_part}#{b_part}
    ands=::Reg::AndMachine.new(progress,*@c_regs#{"+[OB*ends.max]" if b_part})
    #{maybe_progress}catch(:RegAndFail){
    loop{
      progress.bt_stop{
      ands.try_match or #{maybe_progress}throw :RegAndFail
      #p :and_yielding, progress.cursor.pos
      
      yield
      
#      progress.bt_backup
      }
    }
    }
    C
    end    
    
    false&& class Naive
      warn "unimplemented And::Naive"
    end
  end

  #--------------------------------------------------------------
  class AndMachine
  
    class Semaphore<SizedQueue
    #ick, i shouldn't have to build a semaphore in terms of a SizedQueue... 
    #semaphore is the more primitive notion, SizedQueue should be built on it instead
      def initialize
        super(1)
      end
      undef_method :max=,:max,:<<,:push,:pop,:shift

      private :enq,:deq

      def wait
        deq
      end

      def signal
        enq nil
      end

      def signalled?
        size>0
      end
    end
        
    def initialize progress, *regs
      @progress,@regs=progress,regs
      
      @wake_main=Semaphore.new

      @threads=[]
      
      @threadctl=(0...@regs.size).map{Semaphore.new}

      #create a thread for each subexpression
      #each thread gets its own progress.
      #however, all progresses have a dup of 
      #the current cursor as their cursor.
      #threads are used, but they are run successively, not concurrently.
      #each thread starts the next in the series, and the last reawakens
      #the main thread (caller of try_match)
      #because of this serialization, ::Sequences don't need to be thread-safe, (to be used with threads here)
      #nor do we need to worry about backcaptures in one alternative that 
      #are used in a backreference in a subsequent alternative, 
      #creating an order dependancy between them.
      #(such order dependancies should be detected and cause internal reordering
      #to ensure captures threads before corresponding backrefs... not done currently.)
      @longest=nil
      if @regs.size.nonzero? 
        start_thread 0,@progress.cursor.pos
        @wake_main.wait #wait til all children finish
      end
    end
    
    def continuing_to_match progress
      @threads.each{|thr| thr_progress=thr[:progress]
        progress.variable_names.each{|vname|
          progress.raw_register_var vname,thr_progress.raw_variable(vname)
        }
      }
    
    end
    
    def sort_in pair
        @sortedthreads=(0...@threads.size).sort_by{|idx| @threads[idx][:pos]}
    end
        
    def try_match
      
      if @longest
            #after having inheirited its length, reawaken the longest thread
        @threadctl[@longest].signal
      
      end
      
      # @wake_main.wait #wait til all children finish
 
        # if any thread woke us because
        #it failed, return false, 
      if @wake_reason==ThreadFail
        @threads.each{|thr|thr.kill}
        @threads=nil
        return nil
      end
      
      assert @threads.size == @regs.size
      assert @threadctl.size == @regs.size
      
      if @longest
        sort_in @longest
      else
        @sortedthreads=(0...@threads.size).sort_by{|idx| @threads[idx][:pos]}
      end

      warning %#otherwise, need to update progress with side effects from all threads#
      
      #find longest thread
      @longest=@sortedthreads.pop
      
      #p :found_longest, @longest, @wake_reason, @threads.size, t=@threads[1], t && t[:pos]

      #update overall progress with length of longest thread
      @progress.cursor.pos=@threads[@longest][:pos]
      
      #p :end_try_match, @progress.cursor.pos
      
      continuing_to_match(@progress) if respond_to? :continuing_to_match
      
      return true
    end
    
    private
    def start_thread idx,origpos
      #huh "do I really need to create a new progress here?"
      #p=Progress.new(@regs[idx],@progress.cursor.position)
      andprogress=And::ThreadProgress.new(@regs[idx],@progress)
      @progress.child_threads.push @threads[idx]= 
        Thread.new(andprogress,idx,origpos,&method(:thread))
      @threadctl[idx].signal
    end
    
    def vmatch(reg,progress)
      case reg
      when HasCmatch; reg.cmatch(progress){yield}
      when HasBmatch; reg.bmatch(progress) and yield
      else progress.cursor.skip reg and yield
      end
      p -1
      progress.throw
    end
    
    
    ThreadResync=1
    ThreadFail=2
    #
    def thread progress,idx,origpos
      warning %#progress var bindings should backup with @progress's bindings#
      warning %#each thread should wait for all threads that it depends on#
      warning %#need counting semaphores#
      progress.thread=Thread.current
      Thread.current[:progress]=progress
      @threadctl[idx].wait
      #p :start_thread, idx
      cu=progress.cursor
      progress.send($bt_catch_method){
      #p 0
      vmatch(@regs[idx],progress) {
      Thread.current[:pos]=cu.pos
      cu.pos=origpos
      if idx+1<@regs.size and !@longest
        warning %#each thread should awaken the threads dependant on it#
        warning %#need counting semaphores#
        start_thread(idx+1,origpos)
      else
        warning %#should awaken main thread after all subthreads sleep#
        warning %#need counting semaphores#
        @wake_reason=ThreadResync
        @wake_main.signal
        #p 1
      end
      @threadctl[idx].wait
      cu.pos=Thread.current[:pos]
      progress.throw 
      }}
    #ensure
    
        @wake_reason=ThreadFail
        #p 1.9, @wake_main.signalled?
        @wake_main.signal
        #p 2
    end
  
  end
  
  class Variable
    def generate_cmatch
      "@o.cmatch(progress){yield}\n"
    end
    
    def generate_bmatch
      "@o.bmatch(progress)\n"
    end
  end
  
  class InhibitBacktracking < Wrapper
    include HasBmatch
    instance_eval(&WrapCmatch)
    def generate_bmatch
      "@o.bmatch(progress)\n"
    end
  end
  module Reg
    def inhibit_bt
      InhibitBacktracking.new self
    end
  end
end

#--------------------------------------------------------------
#delete all interpreter-related stuff

#constants
::Reg.constants.grep(/MatchSet/).each{|k| 
  ::Reg.__send__ :remove_const, k
}

::Reg::Progress.__send__ :remove_const, :Context

#methods
meths=[]
::Reg.constants.each{|k|
  k=::Reg.const_get k
  if Module===k 
    k.instance_methods.include? "mmatch" and meths<<[k,"mmatch"]
    k.instance_methods.include? "mmatch_full" and meths<<[k,"mmatch_full"]
  end
}

meths+=[[Reg::Progress,"bt_match"],[Reg::Progress,"backtrack"],
        [Reg::Progress,"last_next_match"],[Reg::Reg,"multiple_infection"],
        [Reg::Multiple,"maybe_multiple"]
       ]
        
meths.each{|(k,m)|
  k.__send__ :undef_method,(m)  if k.instance_methods.include? m
}





