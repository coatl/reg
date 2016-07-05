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
$:.push File.expand_path(__FILE__+"/../..") 
require 'test/test_reg'
require 'test/regitem_thattest'
$:.pop

class Array

  alias to_s_without_warn to_s

  def to_s
    warn "calling Array#to_s from #{caller[0]}; but semantics have changed in 1.9"
    to_s_without_warn
  end
end
