require 'regarray'
module Reg

  #--------------------------
  class Repeat
    include Reg,Backtrace,Multiple,Composite

    attr :times

    def max_matches; @times.end end

    def regs(ri) @reg end

    def initialize(reg,times)
      Integer===times and times=times..times
      times.exclude_end? and times=times.begin..times.end-1
      assert times.begin <= times.end
      assert times.begin < Infinity
      assert times.begin >= 0
      assert times.end >= 0
      if Multiple===reg
        class<<self
          #alias mmatch mmatch_full #this doesn't work... why?
          def mmatch(*xx) mmatch_full(*xx); end #have to do this instead
        end
      else
        assert reg.itemrange==(1..1)
        @itemrange=times
      end
      @reg,@times=reg,times
      super
    end

    def itemrange
      defined? @itemrange and return @itemrange
      
      list=Thread.current[:$Reg__Repeat__irs_in_progress]||={}
      list[__id__] and huh
      list[__id__]=1
      i=@reg.itemrange
      rf,rl=i.first,i.last
      tf,tl=times.first,times.last
      @itemrange = rf*tf ..
          if tl==0 or rl==0
            0
          elsif tl==Infinity
            #ought to emit warnings if trouble here...
            #rl==Infinity and maybe trouble
            #rf==0 and trouble
            Infinity
          elsif rl==Infinity
            #...and here
            #maybe trouble #... combinatorial explosion
            Infinity
          else
            rl*tl
           end
    ensure
      list.delete __id__ if list
    end


    def enough_matches? matchcnt,*bogus
      @times===matchcnt
    end

    def inspect
      "(#{@reg.inspect})"+
      if @times.end==Infinity
        if (0..1)===@times.begin
          "."+%w[* +][@times.begin]
        else
        "+#{@times.begin}"
        end
      elsif @times.begin==0
        "-#{@times.end}"
      elsif @times.begin==@times.end
        "*#{@times.begin}"
      else
        "*(#{@times.begin}..#{@times.end})"
      end
    end

    def subregs; [@reg] end

  private

  end






  #--------------------------
  class None; end
  class <<None #class as singleton instance
    include Reg
    def new; self end

    def *(times) 
      times===0 ? Many[0] : self
    end

    def ~; Any;  end

    def &(other); self; end

    def |(other) other.reg end
    def ^(other) other.reg end

    def ===(other); false; end
    def matches_class; self; end
    def inspect; "~OB" end  #hmmmm...
  end


  #--------------------------
  class Any; end
  class <<Any  #maybe all this can be in Object's meta-class....
    include Reg
    
    #any is a singleton
    def new;        self      end

    def *(times)
      Many.new(times)
    end

    def ~; None;  end

    def &(other) 
      if other.itemrange.first>=1
        other.reg 
      else
        And.new(self,other)
      end      
    end

    def |(other); self;  end
    def ^(other); ~other.reg end

    def ===(other); true;end
    def matches_class; ::Object end
    def inspect; "OB" end    #hmmmm...
  end



  #--------------------------
  module HasCmatch; end
  module HasBmatch; end
  class ManyClass
    include Reg
    include Multiple

    class <<self
      @@RAMs={}
      alias uncached__new new
      def new times=0..Infinity
        Range===times and times.exclude_end? and times=times.begin..times.end-1
        @@RAMs[times] ||= uncached__new times
      end
      alias [] new
    end

    def initialize(times=0..Infinity)
      Integer===times and times=times..times
      @times=times
      extend @times.begin==@times.end ? HasBmatch : HasCmatch
#      super
    end

    def mmatch(arr,start)
      left=arr.size-start
      beg=@times.begin
      if beg==left ; [arr[start..-1],left]
      elsif beg<left
        SingleRepeatMatchSet.new([left,@times.end].min, -1, beg)
      end
    end

    def subregs; [Any]  end

    def inspect
      if @times.end.to_f.infinite?
        if @times.begin.zero?
          "Many"
        else
          "(Any+#{@times.begin})"
        end
      elsif @times.begin==@times.end
        "(Any*#{@times.begin})"
      elsif @times.begin.zero?
        "(Any-#{@times.end})"
      else
        "(Any*(#{@times}))"
      end
    end
    
    def l; ManyLazyClass.new(@times) end
    def g; self end
    
    def itemrange; @times end
  end
  
  #--------------------------
  class ManyLazyClass
    include Reg
    include Multiple

    class <<self
      @@RAMs={}
      alias uncached__new new
      def new times=0..Infinity
        Range===times and times.exclude_end? and times=times.begin..times.end-1
        @@RAMs[times] ||= uncached__new times
      end
      alias [] new
    end

    def initialize(times=0..Infinity)
      Integer===times and times=times..times
      @times=times
#      super
    end

 
    def subregs; [Any]  end

    def inspect
      if @times.end.to_f.infinite?
        if @times.begin.zero?
          "Many"
        else
          "(Any+#{@times.begin})"
        end
      elsif @times.begin==@times.end
        "(Any*#{@times.begin})"
      elsif @times.begin.zero?
        "(Any-#{@times.end})"
      else
        "(Any*(#{@times}))"
      end+".l"
    end
    
    def mmatch(arr,start)
      left=arr.size-start
      beg=@times.begin
      if beg==left ; [arr[start..-1],left]
      elsif beg<left
        SingleRepeatMatchSet.new(beg, 1, [left,@times.end].min)
      end
    end
  
       def g; ManyClass.new(@times) end
       def l; self end
    
  end
  
  
  Many=ManyClass.new
  class<<Many
    extend Forwardable
    def_delegators ManyClass, :new, :[]
  end

  #--------------------------
  class <<::Object
    _Objects_class=::Object.__id__
    define_method :reg do
      __id__==_Objects_class ? Any : Fixed.new(self)
    end
  end
  OB=Any
  OBS=Many

if false #traditional and uncomplicated version of OB and OBS  
    OB=::Object.reg
    OBS=OB+0  #std abbreviation for 0 or more of anything
    def OBS.inspect
      "OBS"
    end
    def OB.inspect
      "OB"
    end  
end

end
