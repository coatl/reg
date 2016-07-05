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


module Reg
  module Reg
    def self.event(name)
      EventEmitter.new name
    end
    
    def fail_on(name)
      EventReceiver.new(self,name)
    end
    
    def succeed_on(name)
      EventReceiver.new(self,name,true)
    end
  
  end

  class EventEmitter
    include Reg
    def initialize name
      @name=name
      @name=@name.to_sym
    end
    
    def === other
      throw @name
    end
  end

  class EventReceiver
    include Reg
    def initialize reg,name,result=false
      @reg,@name,@result=reg,name,result
      @name=@name.to_sym
    end
    
    def === other
      flag=nil
      result=catch @name do
        x= @reg===other ; flag=true ; x
      end
      flag ? result : @result
    end
  end

  def self.event(name); Reg.event(name) end
end
