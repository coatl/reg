$Debug=1
require 'reg'
r1=+[Reg::And.new(-[])]
r2=+[-[]&1]


GC.start
origcounts={}
origcounts.default=0
ObjectSpace.each_object{|obj| origcounts[obj.class]+=1 }

10000.times {|n|  
  STDERR.print "." if n.&(0x7F).zero?; STDERR.flush
  r1===[] or fail "empty data fail at iteration #{n}"
  r2===[] and fail "empty data fail at iteration #{n}"
  r2===[1]  or fail "fail at iteration #{n}" }

p Thread.list

r1=r2=nil
GC.start
p Thread.list

counts={}
counts.default=0
ObjectSpace.each_object{|obj| counts[obj.class]+=1 }
require 'pp'
pp counts.map{|(cl,num)| [cl,num-origcounts[cl]]}.sort_by{|pair| pair.last}
