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
+[1,2,3]

def ===(other)
cu=other.to_sequence
cu.scan 1 and cu.scan 2 and cu.scan 3 and cu.eof?
end

generic ===:
def ===(other)
pr=Progress.new self,other.to_sequence
  cu=pr.cursor
catch :RegMatchSucceed {catch :RegMatchFail {
@seq.cmatch pr { cu.eof? ? throw(:RegMatchSucceed, true) : throw(:RegMatchFail) }
}}
end


Seq=-[1,1.5]|-:foo

def cmatch(progress)
  cu=progress.cursor
progress.bt_stop
catch(:RegMatchFail) {(cu.scan 1 and cu.scan 1.5 ) and yield}
progress.bt_backup
progress.bt_stop
catch(:RegMatchFail) {(cu.scan -:foo) and yield}
progress.bt_backup
throw :RegMatchFail
end


+[Seq,2,3] 

def ===(other)
pr=Progress.new other.to_sequence
  cu=pr.cursor
catch :RegMatchSucceed {catch :RegMatchFail {
Seq.cmatch pr { (cu.scan 2 and cu.scan 3 and cu.eof?) ? throw(:RegMatchSucceed, true) : throw :RegMatchFail  }
}}
end
  --or--
def ===(other)
pr=Progress.new other.to_sequence
  cu=progress.cursor
catch :RegMatchSucceed {catch :RegMatchFail {
rest=proc {(cu.scan 2 and cu.scan 3 and cu.eof?) ? throw(:RegMatchSucceed, true) : throw :RegMatchFail }
progress.bt_stop
catch(:RegMatchFail) {(cu.scan 1 and cu.scan 1.5 ) and rest[] }
progress.bt_backup
progress.bt_stop   #optimize away
catch(:RegMatchFail) {(cu.scan -:foo) and rest[] }
progress.bt_backup #optimize away
throw :RegMatchFail #optimize -> false
}}
end

-[0,1,Seq]
def cmatch(progress)
cu=progress.cursor
cu.scan 0 and cu.scan 1 and Seq.cmatch progress{yield} 
throw :RegMatchFail 
end

-[0,1,Seq,Seq2]
def cmatch(progress)
cu=progress.cursor
cu.scan 0 and cu.scan 1 and Seq.cmatch progress{Seq2.cmatch progress {yield}} 
throw :RegMatchFail 
end

-[0,1,Seq,Seq2,2,3]
def cmatch(progress)
cu=progress.cursor
cu.scan 0 and cu.scan 1 and 
Seq.cmatch progress{Seq2.cmatch progress {
cu.scan 2 and cu.scan 3 and yield
throw :RegMatchFail
}} 
end


Numeric-1
def cmatch(progress)
cu=progress.cursor
progress.bt_stop
catch(:RegMatchFail) {cu.scan Numeric and yield}
progress.bt_backup
yield
end

Seq2=Symbol*(1..2)
def cmatch(progress)
cu=progress.cursor
cu.scan Symbol or throw :RegMatchFail
progress.bt_stop
catch(:RegMatchFail) {cu.scan Symbol and yield}
progress.bt_backup
yield
end

Seq2*4
def cmatch(progress)
Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress {yield}}}}
end

Seq2-2
def cmatch(progress)
cu=progress.cursor
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress { 
progress.bt_stop; 
catch(:RegMatchFail){Seq2.cmatch progress {yield}}; 
progress.bt_backup
}}
progress.bt_backup
yield
end

Seq2-4
def cmatch(progress)
cu=progress.cursor
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress { 
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress { 
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress { 
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress {
yield
}} 
progress.bt_backup
yield
}}
progress.bt_backup
yield
}}
progress.bt_backup
yield
}}
progress.bt_backup
yield
end

Seq2-1
def cmatch(progress)
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress, {yield}}
progress.bt_backup
yield
end

Seq2+0
def cmatch(progress)
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress {cmatch progress {yield}}}
progress.bt_backup
yield
end

Seq2+4
def cmatch(progress)
rest2=proc{
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress, &rest2}
progress.bt_backup
yield
}
Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress, &rest2}}}
end
  --or--
def cmatch(progress)
rest2=proc{
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress{
progress.bt_stop
catch(:RegMatchFail){Seq2.cmatch progress{
rest2[]
}}
progress.bt_backup
yield
}}
progress.bt_backup
yield
}
Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress { Seq2.cmatch progress, &rest2}}}
end

:a<<Seq
def cmatch(progress)
cu=progress.cursor
origpos=cu.pos
Seq.cmatch progress {
catch :RegMatchFail {
progress.register_var(:a,cu[origpos...cu.pos])
yield
}
progress.unregister_var(:a)
throw :RegMatchFail
}
end

BR(:a)
def cmatch(progress)
cu=progress.cursor
cu.readahead( (br_a=progress.var_lookup(:a)).size )==br_a and cu.pos+=br_a.size and yield
throw :RegMatchFail
end

-[:a<<Seq,BR(:a)]
def cmatch(progress)
cu=progress.cursor
origpos=cu.pos
Seq.cmatch progress {
catch :RegMatchFail {
progress.register_var(:a,cu[origpos...cu.pos])
cu.readahead( (br_a=progress.var_lookup(:a)).size )==br_a and cu.pos+=br_a.size and yield
}
progress.unregister_var(:a)
throw :RegMatchFail
}
end


Seq&Seq2&Seq3
def cmatch(progress)
cu=progress.cursor
origpos=cu.pos
ands=AndMachine.new(progress,Seq,Seq2,Seq3)
loop{
  progress.bt_stop
  ands.try_match {
  catch :RegMatchFail {
  yield
  }
  progress.bt_backup
  }
}
end

Seq^Seq2^Seq3
def cmatch(progress)
cu=progress.cursor
origpos=cu.pos
catch :RegXorFail {
(0...@regs.size).each{|i|
catch :RegMatchFail{
@regs[i].cmatch progress {
(i+1...@regs.size).each{|j|
catch :RegMatchFail{
@regs[j].cmatch progress {
throw :RegXorFail #fail whole xor matcher
}
}
}
yield
}
}
throw :RegMatchFail
}
}
throw :RegMatchFail
end
  --or--
Seq^Seq2^Seq3
def xortail(h,progress)
(h...@regs.size).each{|j|
catch :RegMatchFail{
@regs[j].cmatch progress {
throw :RegXorFail #fail whole xor matcher
}
}
}
end

def cmatch(progress)

catch :RegXorFail {
catch :RegMatchFail{Seq.cmatch progress {xortail(1,progress);yield}}
catch :RegMatchFail{Seq2.cmatch progress {xortail(2,progress);yield}}
catch :RegMatchFail{Seq3.cmatch progress {yield}}
}
throw :RegMatchFail
end


Seq>>33
def cmatch(progress)
cu=progress.cursor
origpos=cu.pos
Seq.cmatch progress {
progress.register_replace(origpos...cu.pos,33)
yield
}
end

+{/foo/>>33 => 77..88, OB=>OB}
def bmatch(progress)
cu=progress.cursor
hash=cu.read1
hash.each{|k,v| 
if /foo/===k and (77..88)===v 
progress.register_replace GraphPoint::HashKey.new(hash,k,33)
elsif OB===k and OB===v
else return
end
}
return true
end

+{Rep => 77..88, OB=>OB}
def bmatch(progress)
cu=progress.cursor
hash=cu.read1
hash.each{|k,v|
if Rep===k and (77..88)===v
Rep.replacing(progress,GraphPoint::HashKey,hash,k)
elsif OB===k and OB===v
else return
end
}
return true
end
class Transform
def replacing(progress,gp_class,cntr,idx)
progress.register_replace gp_class.new(cntr,idx,@rep)
end
end
