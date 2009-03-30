$VERBOSE=1
$Debug=1
require 'test/unit'
require 'set'
require 'ostruct'
require 'yaml'

require 'rog'
require 'warning'

def try_require name
  require name
rescue Exception
  nil
end

try_require 'rubygems' 
if try_require("sequence/weakrefset").nil? 
  $:<<"../sequence"  #temp hack
  warning "sequence found via temporary hack"
  try_require 'weakrefset' 
end
try_require 'facets/more/superstruct' 

$Verbose=true

Object
Array
Hash
Struct
:SuperStruct  #
:OpenStruct  
:Set
:SortedSet
:WeakRefSet  
Binding
(Object)
#+self-referencing versions of above

#also need a christmas tree, that incorporates at least one of each
#datum, as many of them as possible self-referencing.
#
#and don't forget repeated data


class A_Class
  def initialize
    @a,@b=1,2
  end
  attr_reader :a,:b
  def ==(other)
    [@a,@b]==[other.a,other.b]
  end
end

class A_Struct < Struct.new(:a,:b)
  def initialize
    self.a=1
    self.b=2
  end
end

class BindingMaker
def get_a_binding
  a=12
  binding
end
def == bm
  BindingMaker===bm
end
end

class RogTest<Test::Unit::TestCase

def test_rog

s1=1.0
s2=2.0
range=s1..s2
s1.instance_variable_set(:@m, range)
s2.instance_variable_set(:@m, range)
ss=Set[s1,s2]
s1.instance_variable_set(:@n, ss)
s2.instance_variable_set(:@n, ss)

s1=1.0
s2=2.0
sss=SortedSet[s1,s2]
s1.instance_variable_set(:@n, sss)
s2.instance_variable_set(:@n, sss)

 sss.inspect  #disable this and tests fail...  why?!?!?
data=[

 3.14159,
 2**2000,

 "string",
 /regexp/,
 Enumerable,
 Class,
 BindingMaker.new.get_a_binding,
 A_Struct.new,
 
   (record = OpenStruct.new
   record.name    = "John Smith"
   record.age     = 70
   record.pension = 300
   record),

 SortedSet[1,2,3],
 1..10,

 [1,2,3],
 {1=>2,3=>4},
 Set[1,2,3],
 (WeakRefSet[*%w[a b c]] rescue warn 'weakrefset test disabled'),
 A_Class.new,
 2,
 :symbol,
 nil,
 true,
 false,
 
 
]
data.each{|datum|
 # p datum
  assert_equal datum, datum
  assert_equal datum, ( dup=eval datum.to_rog )
  assert_equal internal_state(datum), internal_state(dup)
 
  if case datum
     when Fixnum,Symbol,true,false,nil: false
     else true
     end
  datum.instance_eval{@a,@b=1,2}
  assert_equal datum, ( dup=eval datum.to_rog )
  assert_equal internal_state(datum), internal_state(dup)

  datum.instance_eval{@c=self}
  assert_equal datum, ( dup=eval datum.to_rog )
  assert_equal internal_state(datum), internal_state(dup)
  end
}
data.each{|datum|
  if case datum
     when Fixnum,Symbol,true,false,nil: false
     else true
     end
  datum.instance_eval{@d=data}
  assert datum, ( dup=eval datum.to_rog )
  assert internal_state(datum), internal_state(dup)
  end
}

data2=[
 range,
 sss,
 (a=[];a<<a;a),
 (a=[];a<<a;a<<a;a),
 (h={};h[0]=h;h),
 (h={};h[h]=0;h),
 (h={};h[h]=h;h),
 (s=Set[];s<<s;s),
]
data2.each{|datum|
 #p datum
  assert_equal datum.to_yaml, datum.to_yaml
  assert_equal datum.to_yaml, ( dup=eval datum.to_rog ).to_yaml
  assert_equal internal_state(datum).to_yaml, internal_state(dup).to_yaml
 
  if case datum
     when Fixnum,Symbol,true,false,nil: false
     else true
     end
  datum.instance_eval{@a,@b=1,2}
  assert_equal datum.to_yaml, ( dup=eval datum.to_rog ).to_yaml
  assert_equal internal_state(datum).to_yaml, internal_state(dup).to_yaml

  datum.instance_eval{@c=self}
  assert_equal datum.to_yaml, ( dup=eval datum.to_rog ).to_yaml
  assert_equal internal_state(datum).to_yaml, internal_state(dup).to_yaml
  end
}
datum= ((w=WeakRefSet[];w<<w;w) rescue warn 'weakrefset test disabled')
  assert_equal datum.inspect, datum.inspect
  assert_equal datum.inspect, ( dup=eval datum.to_rog ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect
 
  if case datum
     when Fixnum,Symbol,true,false,nil: false
     else true
     end
  datum.instance_eval{@a,@b=1,2}
  assert_equal datum.inspect, ( dup=eval datum.to_rog ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect

  datum.instance_eval{@c=self}
  assert_equal datum.inspect, ( dup=eval datum.to_rog ).inspect
  assert_equal internal_state(datum).inspect, internal_state(dup).inspect
  end

data2.each{|datum| 
  if case datum
     when Fixnum,Symbol,true,false,nil: false
     else true
     end
  datum.instance_eval{@d=data;@e=data2}
#breaks yaml
 # assert_equal datum.to_yaml, ( dup=eval datum.to_rog ).to_yaml
 # assert_equal internal_state(datum).to_yaml, internal_state(dup).to_yaml
  end
}
end

def internal_state x
  list=(x.instance_variables-::Rog::IGNORED_INSTANCE_VARIABLES[x.class]).sort
  [list]+list.map{|iv| x.instance_variable_get(iv)}
end

end

class Binding
  def ==(other)
    Binding===other or return
    to_h==other.to_h
  end
end
