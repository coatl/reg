=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2005, 2016  Caleb Clausen

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

=begin
path specification:
each path is relative to the reg it references into.

in order to support named subexpressions, most reg classes that participate
in paths (the ones listed below) will also take a subreg of the reg as a path
component. regs that cannot accept a subreg are marked with stars

reg classes participating in paths:   and their respective path component:
RegString (=Regexp)                   backref integer index **
RegSymbol                             ditto  **
RegArray                              integer index
RegSubseq                             ditto
RegHash                               hash key (of something that matched) ...value?
RegObject                             name (as sym) ...return value?
RegOr                                 integer index
RegAnd                                ditto
RegXor                                ditto
RegNot                                nil only  *
RegRepeat                             integer index  *
(not really named) RegProc            1 of above, depending on what it returned

*  doesn't take a subreg of the reg as index
** doesn't take a subreg and must be end of path (or before -1)

special components:
-1 means go up one level (like .. in directory paths)




               single  ________fixed
          _____multiple--------
    vector-----variable
               

                 dataclasses
matchers--v    String     Array               
Integer        single     single
String         multiple   single
Regexp         variable   single
Reg::Subseq    var(=>any) var(=>any)
Reg::Array     n/a?       single
Reg::Hash      n/a        single
Reg::Repeat    var(=>any) var(=>any)
Lookahead/back multiple   multiple   (0 really)
~single        single     single
~multiple      multiple   multiple
~vector        multiple   multiple   (0 really; lookahead automatic)


others         n/a        single      


=end

=begin
a Reg::Path is a list of (mostly) pairs of contained in a Reg::Path constructor.
The preferred Reg::Path constructor is the --[...] syntax.

the key (left side) of each pair represents a connector matcher, and the value represents
a value matcher. here's a list of allowed connector matchers:

type   allowed connector matchers
Object Array (+[String|Symbol, __]) , Array (+[Regexp, __]) , Reg::RespondsTo (made like -:foo or -"foo" or -:@foo)
Hash   Any Object, Array of 1 Array|Integer, Reg::Literal, any scalar matcher
Array  Integer,Range of Integer

any reg matcher may be used as a value matcher.

If the value matcher is OB and the connector matcher is of the below, the value matcher (and ** connecting to it)
may be left off, so just the connector matcher is given:

type   allowed standalone connector matchers
Object Array (+[String|Symbol, __]) , Array (+[Regexp, __]) , Reg::RespondsTo (made like -:foo or -"foo" or -:@foo)
Hash   Array of 1 Array|Integer, Reg::Literal, String, Symbol, Regexp
Array  Integer,Range of Integer

Reg::Paths may also contain Reg::Repeat or Reg::Subseq, provided the leaves within
these are ultimately pairs or standalone connector matchers. 

=end


module Reg
  class Subseq
    def -@; Path.new @regs; end
  end

  class Path
    def initialize regs
      @regs=regs
      expand_pairs!
    end

    def === other
      @regs.each{|r|
        case r
        when Integer
        when Range
        when Reg::Literal
        when Array
          case r[0]
          when String,Symbol
          when Regexp
          when Array
          when Integer
          end
        when Reg::RespondsTo
        when Reg::Reg
        else
        end
      }
    end
  end

  module Reg 
    def expand_pairs!
      0.upto(@regs.size-1) do |i|
        item=@regs[i]
        @regs[i]=
          case item
          when Reg::Pair; item #ignore
          when Reg::Repeat,Reg::Subseq; item.dup.expand_pairs!
          else Reg::Pair.new(item,OB)
          end
      end
      return self
    end
  end
  class Repeat
    def expand_pairs!
      item=@reg
      @reg=
          case item
          when Reg::Pair; item #ignore
          when Reg::Repeat,Reg::Subseq; item.dup.expand_pairs!
          else Reg::Pair.new(item,OB)
          end
      return self
    end
  end

end

