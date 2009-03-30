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


module Kernel
private
  def trace(traces)
    if Proc===traces 
      handler=traces
      traces=nil
    else
      handler=proc { |*stuff|
        traces<<[stuff<<Thread.current] unless 
          %r'[/\\:]trace\.rb$'===file
      }
    end

    #what does it return? inquiring minds want to know -- just the proc it was given!
    set_trace_func handler  
    #there's no appearent way to get the previous trace handler... phooey
    begin
      result=yield
    ensure
      #attempt to remain debuggable while restoring the old trace func
      set_trace_func(
        (defined? DEBUGGER__ and (DEBUGGER__.context.method:trace_func).to_proc)
      )
    end
    result
  end
end