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
require 'pp'
require 'regdeferred'

module Reg


  #----------------------------------
  module BackrefLike
    def mmatch(pr)
      huh #need info thats in Progress
    end
    
    def mixmod; BackrefLike end
  end
  #----------------------------------
  class Backref 
    include BlankSlate
    restore :inspect,:extend
    restore :respond_to?
    include Formula
    include BackrefLike
    def initialize(name,*path)
      #complex paths not handled yet
      raise ParameterError.new unless path.empty? 
      @name=normalize_bind_name name
      #super
    end
    
    def formula_value(other,progress)
      progress.lookup_var @name
    end
    
    class<<self
      alias [] new
    end
  end


  #----------------------------------
  module BRLike
    include BackrefLike
    include Reg
    def mixmod; BRLike end
  end
  class BR < Backref
    include BRLike
    restore :respond_to?
    def inspect
      'BR['+@name.inspect+']'
    end
  end
  
  def self.BR(*args) BR.new(*args) end
  def self.BackRef(*args) BackRef.new(*args) end
end
