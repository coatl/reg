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
