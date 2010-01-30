

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
