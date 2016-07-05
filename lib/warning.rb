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
module Kernel
  def warning(msg)
    (
     (defined? $Debug) && $Debug or 
     (defined? $DEBUG) && $DEBUG or 
     (defined? $VERBOSE) && $VERBOSE
    ) or return

    #emit each warning only once
    @@seenit__||={}
    clr=caller[0]
    callerid,mname=clr.match(/^(.*:[0-9]+)(?::in (.*))?$/)[1..2]
    mname=mname[1..-2] if /^`.*'$/===mname
    @@seenit__[callerid] and return
    @@seenit__[callerid]=1
  
    warn [callerid,": warning: (",mname,") ",msg].join
  end  
end
