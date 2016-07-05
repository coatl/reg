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
#list of ruby builtin classes that have a nice literal representation already
Fixnum
Bignum
Float
String
NilClass
TrueClass
FalseClass
Array
Hash
Set #not builtin
Class #if named
Module #if named
Range
Regexp
Symbol

#those that don't have nice literal representations
#(but they could)    
Object   #  KlassName-{...}&Module1&Module2  
Proc    #hard to get at internals (opcodes)
Method  #likewise
UnboundMethod  #likewise
Binding  #??  .... basically, just the same as a hash

#not a chance in hell:
File
IO
Dir
Thread
ThreadGroup
Process
Continuation
