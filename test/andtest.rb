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
