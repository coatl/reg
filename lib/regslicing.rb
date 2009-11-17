=begin
array_slicing=Reg::const
subseq_slicing=Reg::const
hash_slicing=Reg::const
object_slicing=Reg::const

slicing_elem=hash_slicing|array_slicing|object_slicing|1
array_slicing_elems=(slicing_elem|item_that(Integer)>=0|subseq_slicing).+

sequence_slicing=+[array_slicing_elems]
array_slicing.set! Reg::Slicing::Seq&sequence_slicing
subseq_slicing.set! Reg::Slicing::Subseq&sequence_slicing

map_slicing=+[+[OB,+[+[OB,slicing_elem].*]].*]
hash_slicing.set! Reg::Slicing::Hash&map_slicing
object_slicing.set! Reg::Slicing::Object&map_slicing





scalar=Integer|Float|String|Symbol|nil|true|false


huh range
huh proc,method,unboundmethod,thread,process,binding,file,io,class?,module?,continuation,dir,
threadgroup,mutex,conditionvariable,queue
object_graph=Reg::const
array_graph=+[object_graph.*]
hash_graph=+{object_graph=>object_graph}
object_graph.set! (scalar|array_graph|hash_graph|OB) & -{/^@/=>object_graph}
=end

=begin

slicings come in four basic varieties: sequence, subsequence, hash, and object
sequence slicings represent a way to carve up an array. the simplest form is
an array of integers, which represent the indexes at which to break the array
into pieces.
subsequence are very similar to sequence, but represent a subrange of the array.
hash slicings are an ordered list of pairs of hash key matchers and the
corresponding subhash of all keys of the pairs in the hash to be matched which matched that
key matcher-value matcher pair. the usual value in these subhashes is 1, but another
slicing is also allowed.
object slicings are similar to hash slicings except the keys and values are the
names and values of instance variables and (non-side-effect-containing) methods.

any slicing can contain another slicing (except that subsequences can only be in
other subsequences or sequences. this contained or sub-slicing tells you how to slice
up the sub item(s) at that point in the larger slicing.

Slicings::Progress state consists of 3 items:
a root slicing
a path from the root to the current slicing
a backtracking stack

the backtracking stack:
keep a stack of arrays of 3 things: 
  a path from the root to this node, (savedpath)
  number of items to go back when match failure occurs (backcount)
  number of levels to go up when match failure occurs (upcount)
  
upcount can never be decremented below zero. attempts to do so just leave it at zero
backcount cannot be changed unless upcount is zero?....unless savedpath and path are same?

(the first item is a stack, so this is a stack of stacks.)
on backtrack:
  pop the last item off the backtracking stack, and using the values in it:
    restore the path to savedpath
    go up upcount times....? upcount even needed now?
    delete the last backcount items in that level we just went up/down to

on bt_stop:
  push a new array onto the backtracking stack, with
    savedpath set to a (shallow) copy of the current path
    upcount and backcount both 0
    
on newcontext:  #used in these matchers: +[], -[], | & ^ repeat +{} -{}  (~ la lb )?
  make a new slicing, inserted at "current position" in the current slicing
  update path to include newly created slicing

"current position" means
  at the end of sequence and subseq slicings
  in map slicings: inserted into last hash (with key of the 'current key') in the slicing
  replacing the elem at the end of map slicings

'current key'
  i'm not sure where this comes from

on endcontext:  
  remove current slicing from path
  "decrement" upcount?
  (if upcount is already zero, zero out backcount...? no)

after a key (and friends...) matches the current pattern in hash and object matchers  
  push key and its value onto path
  push onto path key with a tentative 'value' of nil,
    to be replaced later once it is known

on match_attempt_success in Reg::Array or Reg::Subseq or logicals :
  push the current cursor position onto current slicing

on match_attempt_fail in logicals (well or and xor, anyway):
  push 0 onto current slicing
=end



=begin
module Reg
  class Slicings<::Array
    def initialize(pattern,*array)
      @pattern=pattern
      replace array
    end
    
    class Progress
      def initialize(root)
        @root=root
        @path=Path[]
      end
      
      attr_reader :root,:path
      
      def newcontext(pattern) 
        current.push pattern.slicing_type.new
        huh 'modify path'
      end
      
      def endcontext
        huh
      end
      
      def match_attempt_starting
        huh
      end
      
      def match_attempt_fail
        huh
      end
      
      def match_attempt_success
        huh  
      end
      
      def current
        @path.last.last
      end
      
      def regsidx
        current.size
      end
      alias ri regsidx
    end
    
    class Sequence<Slicings
      def display
        result={}
        regs=@pattern.subregs
        each_index{|i|
          result[regs[i]]=self[i]
        }
        
        result
      end
      
      def inspect
    "$[#{ 
      idx=-1
      map{|i| 
        idx+=1
        @pattern.subregs[idx]+
          "=>"+
          i.inspect
      }.join(", ")
    }]"
      end
      
      def slice(other)
        lasti=0
        map{|i|
          case i
          when Integer:
            other[lasti...i]
          when Subseq: 
            i.slice other[lasti...i.last]
            i=i.last
          when Hash,Object,Array: 
            i.slice other[lasti]
            i=lasti+1
          else raise "hell"
          end
          
          assert i >= lasti
          
          lasti=i
        }
      end
      
      def delete_everything_after(int)
        slice!(int+1..-1)
      end
    end
    Array=Seq=Sequence
    
    class Subsequence<Sequence
      def inspect
        super.sub /^\$/, "$-" 
      end
    end
    Subseq=Subsequence
    
    class Map<Slicings
      
      alias oldsize size
      def size; oldsize/2 end
      
      def add_pair(key,value)
        assert oldsize%2==0
    push(key,value)
    assert oldsize%2==0
      end
      alias old_subseq_set []=
      alias []= add_pair
      
      def position_of?(key)
        result=nil
        (oldsize-2).step(0,-2){|i|
          key==at(i) and break result=i
        }      
        result
      end
      
      def [](key)
        Integer===key and return slice(key*2,2)
        Range===key and raise "hell"
        pos=position_of?(key)
        pos and return at(pos+1)
      end
      
      def first; slice 0..1 end
      def shift; slice! 0..1 end
      def unshift pair; old_subseq_set(0,0,pair) end
      
      def last; slice -2..-1 end  
      def pop; slice! -2..-1 end
      alias push concat  
      alias << push
      
      
      def display
        result={}
        0.step(oldsize-2,2){|i|
          result[at(i)]=at(i+1)
        }
        result
      end
      
      def inspect
        assert oldsize%2==0
        sum=''
        0.step(oldsize-2,2){|i|
          sum<<at(i).inspect+"=>"+at(i+1).inspect
        }
        "{["+sum+"]}"
      end

      def delete_everything_after(key)
        slice!(position_of?(key)+2..-1)
      end
end

class Object<Map

  def inspect; "o"+inspect end
  
  def slice other
    huh
  end
end

class Hash<Map

  def inspect; "h"+inspect end
  
  def slice other
    huh
  end
end


end
end

=end


#the following 10 classes need to support slicing:
#Reg::Array,Reg::Subseq,Reg::Logicals (all 3), Reg::LookAhead, Reg::LookBack, 
#Reg::Object, Reg::Hash, Reg::RestrictHash


module Reg
  class Slicing
    def initialize(pattern)
      assert Composite===pattern
      @pattern=pattern
    end
    
    def self.for(pattern)
      case pattern
      when ::Reg::Object: Object
      when ::Reg::Hash,::Reg::RestrictHash: Hash
      when ::Reg::Array: Sequence
      when ::Reg::And: And
      when ::Reg::Or, ::Reg::Xor: Or
      when ::Reg::LookAhead, ::Reg::LookBack: LookAB
      when ::Reg::Composite: Subsequence
      else nil
      end
    end
    
    def subseq_length; 1 end
    
  end
 
  class Slicing   
    class Sequence<Slicing
      def initialize(*args)
        @subslicings=[]
        @slicepoints=[]
        super
      end
      
      attr :data, :subslicings
      alias cursor data
      
      def index_structure; Integer; end  #matcher num
 
      def delete_all_after idx
        @subslicings.slice! idx..-1
        @slicepoints.slice! idx..-1
      end

      def revert_cursor_to idx
        cursor.pos=@slicepoints[idx]
      end

      def start_slicing sl,i
        assert @subslicings.size==i
        assert @slicepoints.size==i
        @subslicings.push sl
        @slicepoints.push slicing_length(sl)
      end
      
      def slicing_length sl
          if sl.kind_of? Subsequence
            :placeholder   
          else
            (@slicepoints.last||0)+1
          end
      end
      
      def finish_slicing sl
        assert Subsequence===sl
        assert @slicepoints.last==:placeholder
        @slicepoints[-1]=sl.subseq_length
       
      end
    end
    Array=Seq=Sequence
    
    class Subsequence<Sequence
      def subseq_length
        subslicings.inject(0){|sum,sl| sum+(sl.subseq_length rescue 1) }
      end
    end
    Subseq=Subsequence
    
    class And<Subseq
      def subseq_length
        result=0
        subslicings.each{|sl| 
          len=sl.subseq_length;
          len>result and result=len
        }
        return result
      end    
    end
    
    class Or<Subseq
      def start_slicing sl,i
        huh
      end
    
      def finish_slicing sl
        huh
      end
      
      def subseq_length
        huh
      end
    
    end
    
    class LookAB<Subseq
      def subseq_length; 0 end
    end
    
=begin internal structure of Map
    Map_slicing=Reg::const
    List_slicing=Reg::const
    slicing=Map_slicing|List_slicing|nil

    how_each_matcher_pair_sliced=+[Object, #key of matcher pair
      -[Object, slicing,slicing].*  #key from matching pair of data,key slicing, value slicing
      -[Object, slicing,:placeholder]-1  #last value slicing might not be known yet
    ]
    how_each_literal_sliced=-[Object, slicing]
    Map_slicing.set! -{
      :@literals=>+[how_each_literal_sliced.*],
      :@matchers=>+[how_each_matcher_pair_sliced.*],
      :@ivar_literals=>+[how_each_literal_sliced.*].-, #in objects only
      :@ivar_matchers=>+[how_each_matcher_pair_sliced.*].-, #in objects only
    }
    
    List_slicing.set! -{
      :@slicepoints=>:sps<<+[
        -[:lastint<<Integer, (Pos[-1]|:placeholder|item_that>=BR[:lastint]).la]+0,
        :placeholder.reg.-]
      :@subslicings=>+[slicing*BR[:sps].size]   
    }

=end    
    class Map<Slicing
      def initialize(*args)
        @literals=[]
        @matchers=[]
        super
      end
    
    
   end
    
    class Hash<Map
      def initialize(pattern,data)
        @keys=data.keys.to_sequence
        super(pattern)
      end
      
    
      def index_structure; +[Integer]|+[Integer*2,0.reg|1] end  #literal matcher num | matcher pair num, data pair num, 0=key;1=value
      
      def delete_all_after idx
        if idx.size==3  #in a @matcher
          @matchers.slice!(idx[0]..-1)
          @matchers.last.slice!(1+3*idx[1]..-1)
          idx[2].zero? and @matchers.last[-1]=:placeholder
        else  #in a @literal
          @matchers=[]
          @literals.slice!(2*idx[0]..-1)
        end
      
      
        huh  
      end

      def cursor; @keys end

      def reset_cursor; @keys.begin! end
      
      def revert_cursor_to idx
        cursor.pos= (idx.size==3 ? idx[1] : 0)
      end
      
      def start_literal_slicing sl
        assert @matchers.empty?
        @literals.push @keys[@literals.size/2], sl
      end
      
      def start_matcher_key_slicing sl
        assert @matchers.last.last != :placeholder
        @matchers.last.push @pattern.@matchers[(@matchers.size-1)/3],sl,:placeholder
        assert @matchers.last.last == :placeholder
      end
      
      def start_matcher_val_slicing sl
        assert @matchers.last.last == :placeholder
        @matchers.last[-1]=sl
        assert @matchers.last.last != :placeholder
      end
      
      def start_matcher_default_slicing sl
        assert @literals.size/2==@pattern.@literals.size
        if @matchers.size==@pattern.@matchers.size
          @matchers.push [OB]
        else
          assert @matchers.size==@pattern.@matchers.size+1
        end
        k=huh
        k=(@matchers.last.size-1)/3
        @matchers.last.push @keys[k],nil,sl
      end
    end
    
    class Object<Map
      def initialize(pattern,data)
        @ivarnames=data.instance_variables.to_sequence
        @methnames=data.public_methods.to_sequence
        super
      end
      
      def cursor; huh end
    
      def delete_all_after idx
        huh
      end

      def revert_cursor_to idx
        huh
      end
      
      def start_slicing sl,i
        huh
      end
      
      def finish_slicing sl
        huh
      end
    end
  
  
    class Path
      def initialize
        @indexes=[]
        @slicings=[]
      end    
      
      def dup
        result=super
        @indexes=@indexes.dup
        @slicings=slicings.dup
        result
      end
      
      def push slicing
        @indexes.push 0
        @slicings.push slicing
      end
      
      def pop
        @indexes.pop
        @slicings.pop
      end
      
      def index n=-1; @indexes[n] end
      def index=n; @indexes[-1]=n end
      def slicing n=-1; @slicings[n] end
      
      def [](n); [@indexes[n],@slicings[n]] end
    end
  end
end