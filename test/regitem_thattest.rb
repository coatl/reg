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
require 'test/unit'
  class Object
    #define a more stable version of inspect (for testing purposes)
    alias pristine_inspect inspect
    def inspect
      res=pristine_inspect
      res[/^#</] or return res
      res=["#<",self.class,": ",instance_variables.sort.collect{|v| 
        [v,"=",instance_variable_get(v).inspect," "].join
      }]
      #res.last.last.chop!
      res.push('>')
      res.join
    end
  end
  class T411 < Test::Unit::TestCase
    def test_unnamed
      _=require 'reg'

      _=item_that<4===3
      assert_equal 'true', _.inspect

      _=item_that<4===5
      assert_equal 'false', _.inspect

      assert_nothing_thrown {_=item_that.respond_to?(false)==='ddd'}
    end
  end

