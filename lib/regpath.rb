=begin copyright
    reg - the ruby extended grammar
    Copyright (C) 2005  Caleb Clausen

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
module Reg
class Instances
  class<<self; alias [] new end
  
  def initialize(method)
    @method=method
  end
  
  def unwrap; @method end

end
end