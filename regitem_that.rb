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
require 'regdeferred.rb'

module Reg
  class <<self
    #sugar forwards this from Kernel
    def item_that(klass=nil,&block)
      return ItemThat.new(klass) unless block
       
      class <<block
          # arguments to include appear to be processed in a strange order... this is 
          #significant if order is important to you
          #the #included methods are perhaps not called when i think they should be....
          #(DON'T simplify the next line; it'll break.)
        [BlankSlate ,Formula, BlockLike].each{|mod| include mod}
        restore :inspect,:extend,:call

        alias === eeee #workaround-- shouldn't be needed
        alias formula_value call
  #      undef eeee
      end
      block.klass=klass
      block
    end
    alias item_is item_that
  end

 #----------------------------------
  module BlockLike
#    include Formula

    attr_writer :klass #for internal use only

    def eeee(val)
      @klass and @klass===val || return
      begin call(val)
      rescue: false
      end
    end
    alias === eeee #does nothing in includers.... why?
    def formula_value *a,&b; call( *a,&b) end

    
    def mixmod; ItemThatLike end
    def reg; dup.extend Reg end
  end
  
 #----------------------------------
  module DeferredQuery
  #just an ancestor for ItemThatLike and RegThatLike
    def eee(item)
      formula_value item rescue false
    end
    alias === eee #this doesn't work!!! WHY????
    #there's no way to define the method === in this
    #module and have it be defined in class ItemThat.
    #mixmod and reg don't have this problem. this must
    #be a bug(??). for now, I work around it with clever 
    #alias/undefing in places that include/extend ItemThatLike
    #(seemingly, this is only a problem when including, not extending... dunno why)
    #this bug may be gone now; need to try to get rid of weird eee stuff.
    
  #  def mmatch(pr)
  #    !pr.cursor.eof? and self===pr.cursor.readahead1 and [true,1]
  #  end
  
  end
  
  #----------------------------------
  module ItemThatLike
    include DeferredQuery
    
    def mixmod; ItemThatLike end
    def reg; dup.extend RegThatLike end
    
    
    #I should really consider adding better definitions of to_str, to_ary, (maybe) to_proc here
    #respond_to? would be a good one too.
    #or even in Deferred, maybe
    #as it is, all kinds of weird stuff happens if respond_to? and to_ary both return true values,
    #(which they do currently)
  end
  
  #----------------------------------
  class ItemThat 
    include BlankSlate
    restore :inspect,:extend
    include Formula
    include ItemThatLike
    alias === eee
    undef eee
    def initialize(klass=nil)
      @klass=klass
    end
    
    def formula_value(val,*rest)
      #the exception raised here should be (eventually) caught by 
      #the handler in ItemThatLike#eee. calling ItemThat#formula_value isn't
      #really legitimate otherwise.
      @klass and @klass===val || fail("item_that constraint mismatch")
    
      val
    end
    
  end

  #----------------------------------
  module RegThatLike
    include DeferredQuery
    include Reg
    
    def mixmod; RegThatLike end
    def reg; self end
  end
  
  #----------------------------------
  class RegThat < ItemThat
    include RegThatLike
  end
  
  #----------------------------------
  nil&&class RegThat
    include BlankSlate
    restore :inspect,:extend
    include Formula
    include RegThatLike
    alias === eee
    undef eee
    def initialize(klass=nil)
      @klass=klass
      super
    end
    
    def formula_value(val,*rest)
      #the exception raised here should be (eventually) caught by 
      #the handler in RegThatLike#eee. calling RegThat#formula_value isn't
      #really legitimate otherwise.
      @klass and @klass===val || fail("reg_that constraint mismatch")
    
      val
    end
    
  end

end