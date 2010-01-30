#$:<< File.dirname(__FILE__)
require 'test/test_reg'
require 'test/regitem_thattest'

class Array

  alias to_s_without_warn to_s

  def to_s
    warn "calling Array#to_s from #{caller[0]}; but semantics have changed in 1.9"
    to_s_without_warn
  end
end
