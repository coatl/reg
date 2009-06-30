#!/usr/bin/ruby -w 
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
$VERBOSE=true
$Debug=true #turn on assertions

require "reg"
require 'getoptlong'


warn "hrm, it seems like many of these tests are not running, for whatever reason"

unless ENV['NO_TEST_UNIT']
  require 'test/unit'  #gets in the way of my debug output
  class TC_Reg < Test::Unit::TestCase; end
end

class TC_Reg 
#  class <<self


  def randsym
    as=Symbol.all_symbols
    as[rand(as.size)]
  end

  def makelendata(num=20,mask=0b11111111111,mischief=false)
    result=[]
    (1..num).each do
      begin type=rand(11) end until 0 != mask&(1<<type)
      len=type==0 ? 0 : rand(4)

      result<<case type
        when 0    then [0]
        when 1 then [len]+(1..len).map{randsym}
        when 2 then (1..len).map{randsym}+[-len]
        when 3 then (1..len).map{randsym}+["infix#{len}"]+(1..len).map{randsym}
        when 4
          [:Q] +
            (1..len).map{randsym}.delete_if {|x|:Q==x} +
            (1..rand(4)).map{randsym}.delete_if {|x|:Q==x} +
          [:Q]
        when 5
          [:Q] +
            (1..len).map{randsym}.delete_if {|x|:Q==x} +
            [:'\\', :Q] +
            (1..rand(4)).map{randsym}.delete_if {|x|:Q==x} +
          [:Q]

        when 6
          [:q]+(1..len).map{randsym}.delete_if {|x|:q==x}+[:q]

        when 7
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 8
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:'\\', 0==rand(1) ? :begin : :end] +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 9
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:begin]+(1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +[:end]+
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]

        when 10
          [:begin]+
            (1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:'\\', 0==rand(1)? :begin : :end] +
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
            [:begin]+(1..len).map{randsym}.delete_if {|x| :begin==x or :end==x} +[:end]+
            (1..rand(4)).map{randsym}.delete_if {|x| :begin==x or :end==x} +
          [:end]
      end
    end
    mischief and result.insert(rand(result.size),mischief)
    return result
  end
  
  def rand_ambig
    nestlevel=rand(5)+1
    corepat=rand(1)==0 ? 'OB' : 'Numeric.reg'
    pat=corepat
    product=1
    nestlevel.times { 
      op=case rand(3)
           when 0: :*
           when 1: :+
           when 2: :-
         end
      num=rand(6)+1
      product*=num
      pat=["(",pat,")",op,num].to_s 
      product>50 and break
    }
    
    pat=eval "+[#{pat}]"
    $verbose and print "testing #{pat.inspect} with #{product} items\n"
    assert_eee pat,(1..product).to_a
  end
  
  def disabled_test_rand_reg   #causes 0*inf too often
    20.times { rand_ambig }
  end
  
  def begin_end_pattern op, val
     innerbe=Reg::const
     innerbe.set! -[:begin, (
           ~/^(begin|end|\\)$/.sym |
           -[:'\\',OB] |
           innerbe
         ).send(op,val), :end]
    
  end
 
  def test_object_matcher 
     #object matcher tests
     ob=AnyStruct[:aa=>1,:b=>"foob",:c=>[1,2,3]]
     assert_eee Rob(:aa=>1), ob
     assert_eee Rob(:@aa=>1), ob
     assert_eee Rob(:aa=>1,:b=>/foo/), ob
     assert_eee Rob(:@aa=>1,:@b=>/foo/), ob

     assert_ene Rob(:aa=>Float), ob
     assert_ene Rob(:@aa=>Float), ob
     assert_ene Rob(:aa=>1,:b=>/fu/), ob
     assert_ene Rob(:@aa=>1,:@b=>/fu/), ob
 
     assert_eee Rob(), ob
     assert_ene Rob(:d=>item_that.size>33), ob

     
     assert_eee Rob(/aa$/=>1), ob
     #assert_eee Rob(/@aa/=>1), ob
     assert_eee Rob(/aa$/=>1,:b=>/foo/), ob
     #assert_eee Rob(/@aa/=>1,:@b=>/foo/), ob

     assert_ene Rob(/aab$/=>1), ob
     assert_ene Rob(/aab$/=>1,:b=>/foo/), ob

     assert_ene Rob(/aa$/=>Float), ob
     #assert_ene Rob(/@aa/=>Float), ob
     assert_ene Rob(/aa$/=>1,:b=>/fu/), ob
     #assert_ene Rob(/@aa/=>1,:@b=>/fu/), ob
 
     assert_ene Rob(/ddd/=>item_that.size>33), ob
     
     assert_eee Rob(/aa$/=>1,:b=>/foo/,:@c=>OB), ob
     #assert_eee Rob(/@aa/=>1,:@b=>/foo/,OB=>item_that.size<33), ob
     #assert_eee Rob(/@aa/=>1,:@b=>/foo/,:@c=>Array,OB=>nil), ob

     assert_ene Rob(/a$/=>1,:bb=>/foo/,:@c=>OB), ob
     #assert_ene Rob(/@a/=>1,:@b=>/foo/,OB=>item_that.size>33), ob
     #assert_ene Rob(/@a/=>1,:@b=>/foo/,:@c=>Array,OB=>Symbol), ob
  end
  
  def test_hash_matcher
     h={}
     h.default=:b
     check_hash_matcher Rah(:a=>:b), :matches=>[{:a=>:b},h],
       :unmatches=>[ {:a=>:c}, {} ] #=> false

     check_hash_matcher Rah(/^(a|b)$/=>33), 
       :matches=>[{"a"=>33}, {"b"=>33}, {"a"=>33,"b"=>33} ],
       :unmatches=>[
         {"a"=>33,"c"=>33},
         {"b"=>33,"c"=>33}, {"a"=>33,"c"=>133}, {"b"=>33,"c"=>133}, {"a"=>133}, {"b"=>133} ,
         {"c"=>33}, {"c"=>133}  , {"a"=>33,"b"=>133}, {"a"=>133,"b"=>33}, {"a"=>133,"b"=>133}  
       ]

=begin disabled.... Reg::Hash#|(Hash) not special anymore
     assert_eee Rah("a"=>33)|{"b"=>33}, {"a"=>33,"b"=>33}  #=> true
     assert_eee Rah("a"=>33)|{"b"=>33}, {"a"=>33,"b"=>133}  #=> true
     assert_ene Rah("a"=>33)|{"b"=>33}, {"a"=>133,"b"=>33}  #=> false
     assert_ene Rah("a"=>33)|{"b"=>33}, {"a"=>133,"b"=>133}  #=> false

     assert_eee Rah("a"=>33)|{"b"=>33}, {"b"=>33}  #=> true
=end
     check_hash_matcher Rah(:a.reg|:b => 44), :matches=>[{:a => 44},{:b => 44}],
       :unmatches=> [{:a => 144}, {:b => 144}]


     check_hash_matcher( +{OB=>6}, :unmatches=>{} )

     check_hash_matcher( +{/fo+/=>8, /ba+r/=>9}, :matches=> {"foo"=>8,"bar"=>9})

     check_hash_matcher(
       hm=+{:foo=>:bar,   1=>/flux/,   (2..10)=>"zork",
          ("r".."s")=>item_that.reverse,   (11..20)=>NilClass|"fizzle",
          Array=>Enumerable|nil,   OB=>Integer
          },
       :matches=>[{:foo=>:bar,   1=>"flux",   2=>"zork",   "r"=>"a string", 
        11=>"fizzle",   []=>(9..99),   :rest=>3**99},
       {:foo=>:bar,   1=>"flux",   2=>"zork",   "r"=>"a string", 
          :rest=>3**99},
       {:foo=>:bar,   1=>"flux cap",   3=>"zork",   "rat"=>"long string",   String=>4**99}
       ],
       :unmatches=>[
       {:foo=>:bar,   1=>"flux",   2=>"zork",   "r"=>"a string", 
        11=>"fizzle",   []=>(9..99),   :rest=>3**99,   :fibble=>:foomp},
       {:foo=>:baz,   1=>"flux",   2=>"zork",   "r"=>"a string",   
        11=>"fizzle",   []=>(9..99),   :rest=>3**99},
       {:foo=>:bar,   2=>"zork",   "r"=>"a string",   
        11=>"fizzle",   []=>(9..99),   :rest=>3**99}
       ]
     )


     check_hash_matcher(
        hm=+{:foo=>:bar,   1=>/flux/,   item_that<10=>"zork",
          /^[rs]/=>item_that.reverse,   item_that>10=>NilClass|"fizzle",
          Array=>Enumerable|nil,   OB=>Integer
        }, 
        :matches=>[{:foo=>:bar,   1=>"flux",   2=>"zork",   "r"=>"a string", 
            11=>"fizzle",   []=>(9..99),   :rest=>3**99},
          {:foo=>:bar,   1=>"flux cap",   3=>"zork",   "rat"=>"long string",   String=>4**99}
        ],
        :unmatches=>[{:foo=>:bar,   1=>"flux",   2=>"zork",   "r"=>"a string", 
                 11=>"fizzle",   []=>(9..99),   :rest=>3**99,   :fibble=>:foomp},
       {:foo=>:baz,   1=>"flux",   2=>"zork",   "r"=>"a string",   
        11=>"fizzle",   []=>(9..99),   :rest=>3**99},
       {:foo=>:bar,   2=>"zork",   "r"=>"a string",   
        11=>"fizzle",   []=>(9..99),   :rest=>3**99} 
        ]
      )

     check_hash_matcher(
       +{1=>Set[1,2,3]}, 
       :matches=>[{1=>1}, {1=>2}],
       :unmatches=>[{1=>4}, {1=>Set[1,2,3]}] 
     )

  
  end
  
  def test_recursive_itemrange
     be=begin_end_pattern :+, 0

     be1=begin_end_pattern :+, 1
     #minlen == 1 + min(1,2,minlen)*1 + 1

     be2=begin_end_pattern :*, 2
     
     be10=begin_end_pattern :*,2..5
     #maxlen == 1 + max(1,2,maxlen)*5 + 1



     assert_equal 0..0, (+[]).subitemrange
     assert_equal 0..0, ::Reg::var.set!(+[]).subitemrange
     assert_equal 1..1, (+[1]).subitemrange
     assert_equal 1..1, ::Reg::var.set!(+[1]).subitemrange
     assert_equal 2..2, (+[1,1]).subitemrange
     assert_equal 2..2, ::Reg::var.set!(+[1,1]).subitemrange

     assert_range_could_be_conservative_approx( 2..Infinity, be.itemrange ) #illegal instruction
     assert_range_could_be_conservative_approx( 2..Infinity, be.subitemrange )
     
     assert_range_could_be_conservative_approx( 3..Infinity, be1.itemrange )
     assert_range_could_be_conservative_approx( 3..Infinity, be1.subitemrange )
     
     assert_range_could_be_conservative_approx( 4..Infinity, be2.itemrange )
     assert_range_could_be_conservative_approx( 4..Infinity, be2.subitemrange )  
    
     assert_range_could_be_conservative_approx( 4..Infinity, be10.itemrange )
     assert_range_could_be_conservative_approx( 4..Infinity, be10.subitemrange )  
  end
  
  def assert_range_could_be_conservative_approx expected, actual
    if expected==actual 
      assert true
    else 
      assert (0..Infinity)==actual 
      warning "conservative approximation accepted for recursive matcher's itemrange"
    end
  end
  
  def test_recursive_inspect
  
     var=Reg::var
     
     #Reg::Var#inspect should not be using Recursive (tho its ok for Reg::Const...)
     #and the tests here should not require it to!
     var.set!( +[var] )
     assert_eee( /^\Recursive\(var(\d+)=\{\}, \+\[var\1\]\)$/, var.inspect )
     var.set!( -[var.-] )
     assert_eee( /^\Recursive\(var(\d+)=\{\}, \-\[\(?var\1\)?(\.-|-1)\]\)$/, var.inspect )
     
#     huh "actual patterns to match tbd"
     var.set!( +{var=>1} )
     assert_eee /^Recursive\(var(\d+)=\{\}, \+\{-\[\(var\1\)-1\]=>1\}\)$/, var.inspect
     var.set! +{1=>var}
     assert_eee /^Recursive\(var(\d+)=\{\}, \+\{1=>var\1\}\)$/, var.inspect
     var.set! -{:foo=>var,1=>2}
     assert_equal var.inspect, ''
     var.set! -{:foo=>var}
     assert_equal var.inspect, ''

     var.set! +{var=>1|nil}
     assert_equal var.inspect, ''
     var.set! -{:foo=>var|nil}
     assert_equal var.inspect, ''

     var.set! +{var=>1.reg.-}
     assert_equal var.inspect, ''

     var.set! -{:foo=>var.-}
     assert_equal var.inspect, ''




     var=Reg::const
     var.set! +[var]
     assert_eee /^\Recursive\(var(\d+)=\{\}, \+\[var\1\]\)$/, var.inspect
     assert_raises(RuntimeError) {var.set! 0}

     var=Reg::const
     var.set! -[var.-]
     assert_eee /^\Recursive\(var(\d+)=\{\}, \-\[\(?var\1\)?(\.-|-1)\]\)$/, var.inspect
     assert_raises(RuntimeError) {var.set! 0}
     
#     huh "actual patterns to match tbd"

     var=Reg::const
     var.set! +{var=>1}
     assert_eee /^Recursive\(var(\d+)=\{\}, \+\{-\[\(var\1\)-1\]=>1\}\)$/, var.inspect
     assert_raises(RuntimeError) {var.set! 0}

     var=Reg::const
     var.set! +{1=>var}
     assert_eee /^Recursive\(var(\d+)=\{\}, \+\{1=>var\1\}\)$/, var.inspect
     assert_raises(RuntimeError) {var.set! 0}

     var=Reg::const
     var.set! -{:foo=>var,1=>2}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}

     var=Reg::const
     var.set! -{:foo=>var}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}


     var=Reg::const
     var.set! +{var=>1|nil}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}


     var=Reg::const
     var.set! -{:foo=>var|nil}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}


     var=Reg::const
     var.set! +{var=>1.reg.-}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}




     var=Reg::const
     var.set! -{:foo=>var.-}
     assert_equal var.inspect, ''
     assert_raises(RuntimeError) {var.set! 0}
  end
  
  def test_ordered_hash_matcher
    m=[ Object**1, Enumerable**2, ::Array**3, 
       +[OB-20]**4, +[OB-19]**5, +[OB-18]**6, +[OB-17]**7,
      +[Integer, Integer]**8, +[item_that<4, Integer]**9, +[item_that<4, item_that**2>9]**10 
    ].reverse.+@     
    assert_eee m, {[2,4]=>10, [2,1]=>9, [5,0]=>8, [nil]*17=>7, [nil]*18=>6, [nil]*19=>5, 
                   [nil]*20=>4, [nil]*100=>3, {}=>2, nil=>1
                  }
  
  
  end
  
  def test_backtracking_to_inner_array
    m=+[ BR[:b] ]
    
    assert_ene m, []
    assert_ene m, [1]
    
    m=+[ -[]%:b,BR[:b] ]
    
    assert_eee m, []
    assert_ene m, [1]
    
  
    m=+[  -[/k/.-%:a, OBS], BR[:a] ]
    
    assert_eee m, ['k',99, 'k']
    assert_eee m, ['k',99]
    assert_eee m, [99]

    m=+[  +[/k/.-%:a, OBS], BR[:a] ]
    
    assert_eee m, [['k',99], 'k']
    assert_eee m, [['k',99]]
    assert_eee m, [[99]]

    m=+[  +[(/k/%:a).-, OBS], Range ]
    
    assert_ene m, [['k',99], 'k']
    assert_ene m, [['k',99]]
    assert_ene m, [[99]]

    m=+[  +[(/k/%:a).-, OBS], BR[:a] ]
    
    assert_eee m, [['k',99], 'k']
    assert_ene m, [['k',99]]
    assert_ene m, [[99]]


    m=+[  +[/k/.-%:a, Integer.*], BR[:a] ]
    
    assert_eee m, [['k',99], 'k']
    assert_ene m, [['k',99]]
    assert_eee m, [[99]]


     #backreference to something in a nested array
     assert_eee( +[1,2,3,+[OB*(1..2)%:a,OB*(1..2)],BR(:a)], [1,2,3,[4,5,6],4,5] )

     #backtracking should work in nested Reg::Array
     assert_eee( +[1,2,3,+[OB*(1..2)%:a,OB*(1..2)],BR(:a)], [1,2,3,[4,5,6],4] )
   end
   
   
  def test_backtracking_in_heterogeneous_data_stuctures
     #backreference to something in a nested array in a nested hash
     assert_eee( +{:foo=>+[OB*(1..2)%:a,OB*(1..2)]}, {:foo=>[4,5,6]} )
     assert_eee( +[1,2,3,+{:foo=>+[OB*(1..2)%:a,OB*(1..2)]},BR(:a)], [1,2,3,{:foo=>[4,5,6]},4,5] )

     #backtracking should work in nested Reg::Array in Reg::Hash or the like
     assert_eee( +[1,2,3,+{:foo=>+[OB*(1..2)%:a,OB*(1..2)]},BR(:a)], [1,2,3,{:foo=>[4,5,6]},4] )


     #...also do eg backtracking in reg::object... what else?
  end
  
  
  def test_finally
    puts=nil
    assert_eee( +[  OB.finally{|p| puts= :foop}],[99] )
    assert_equal :foop, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).finally{|p| puts= :foop}],],[99] )
    assert_equal :foop, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).finally{|p| puts= p[:a]}],],[99] )
    assert_equal 99, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).-.finally{|p| puts= p[:a]}],],[99] )
    assert_equal 99, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).-.finally{|p| puts= p[:a]}, OBS],],[99] )
    assert_equal 99, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).-.finally{|p| puts= p[:a]}, OBS],],[99,100] )
    assert_equal 99, puts
    puts=nil
    assert_eee( +[  -[(OB%:a).-.finally{|p| puts= p[:a]}, OBS],],[99,100,101] )
    assert_equal 99, puts
    puts=nil
    assert_ene( +[  -[(OB%:a).-.finally{|p| puts= p[:a]}, 5],],[999,6] )
    assert_equal nil, puts
  end  
   
  def test_later
    puts=puts2=nil
    assert_eee( +[  -[(OB%:a).-.later{|p| puts= p[:a]}, OBS],],[99] )
    assert_equal 99, puts
    assert_eee( +[ (OB%:a).later{|p| puts= p[:a]}, OBS ], [9] )
    assert_equal 9, puts
    assert_eee( +[ OB.later{|p| puts= 8}, OBS ], [88] )
    assert_equal 8, puts
    assert_ene( +[  -[(OB%:a).-.later{|p| puts2= 1}, 5],],[999,6] )
    assert_equal nil, puts2
    assert_ene( +[  -[OB.later{|p| puts2= 1}, 5],],[999,6] )
    assert_equal nil, puts2
  end  
   
  def test_side_effect
    puts=puts2=nil
    assert_eee( +[  -[(OB%:a).-.side_effect{|p| puts= p[:a]}, OBS],],[99] )
    assert_equal 99, puts
    assert_eee( +[ (OB%:a).side_effect{|p| puts= p[:a]}, OBS ], [9] )
    assert_equal 9, puts
    assert_eee( +[ OB.side_effect{|p| puts= 8}, OBS ], [88] )
    assert_equal 8, puts
    assert_ene( +[  -[(OB%:a).-.side_effect{|p| puts2= p[:a]}, 5],],[999,6] )
    assert_equal 999, puts2
  end  
   
  def test_undo
    puts=puts2=nil

    assert_eee( +[  -[(OB%:a).-.side_effect{|p| puts2= p[:a]}.undo{puts2=nil}, 5],],[999,6] )
    assert_equal nil, puts2

    assert_eee( +[  OB.side_effect{|p| puts2= 1}.undo{puts2=nil}, 66,],[99,66] )
    assert_equal nil, puts2

    assert_eee( +[  OB.side_effect{|p| puts2= 1}.undo{puts2=false}, 66,],[99,66] )
    assert_equal false, puts2
  end  
   
  
  def test_backtracking_in_ordered_hash
    assert_eee( +[:foo.reg**+[OB.-%:a,OB.-], :bar.reg**+[BR[:a]]], {:foo=>[1], :bar=>[1]} )
    assert_eee( +[:foo.reg**+[OB.-%:a,OB.-], :bar.reg**+[BR[:a]]], {:foo=>[1], :bar=>[]} )

    assert_eee( +[:foo.reg**+[OB.-,OB.-%:a], :bar.reg**+[BR[:a]]], {:foo=>[1], :bar=>[1]} )
    assert_eee( +[:foo.reg**+[OB.-,OB.-%:a], :bar.reg**+[BR[:a]]], {:foo=>[1], :bar=>[]} )

    assert_eee( +[:foo.reg**+[OB*(1..2)%:a,OB*(1..2)], :bar.reg**+[BR[:a]]], {:foo=>[1,1,1], :bar=>[1]} )
    assert_eee( +[:foo.reg**+[OB*(1..2)%:a,OB*(1..2)], :bar.reg**+[BR[:a]]], {:foo=>[1,1,1], :bar=>[1,1]} )
  end
   

  def test_backtracking_from_value_to_key_in_hash
    assert_ene( +{+[OB.-%:a,OB.-]=>+[BR[:a]]}, {[1,2,3]=>[1]} )
    assert_eee( +{+[OB.-%:a,OB.-]=>+[BR[:a]]}, {[1,2]=>[1]} )
    assert_eee( +{+[OB.-%:a,OB.-]=>+[BR[:a]]}, {[1]=>[1]} )
    assert_eee( +{+[OB.-%:a,OB.-]=>+[BR[:a]]}, {[1]=>[]} )

    assert_ene( +{+[OB.-,OB.-%:a]=>+[BR[:a]]}, {[3,2,1]=>[1]} )
    assert_eee( +{+[OB.-,OB.-%:a]=>+[BR[:a]]}, {[2,1]=>[1]} )
    assert_eee( +{+[OB.-,OB.-%:a]=>+[BR[:a]]}, {[1]=>[1]} )
    assert_eee( +{+[OB.-,OB.-%:a]=>+[BR[:a]]}, {[1]=>[]} )

    assert_eee( +{+[OB*(1..2)%:a,OB*(1..2)]=>+[BR[:a]]}, {[1,1,1]=>[1]} )
    assert_eee( +{+[OB*(1..2)%:a,OB*(1..2)]=>+[BR[:a]]}, {[1,1,1]=>[1,1]} )
    assert_eee( +{+[OB*(1..2),OB*(1..2)%:a]=>+[BR[:a]]}, {[1,1,1]=>[1]} )
    assert_eee( +{+[OB*(1..2),OB*(1..2)%:a]=>+[BR[:a]]}, {[1,1,1]=>[1,1]} )

    assert_ene( +[+[OB.-%:a,OB.-]**+[BR[:a]]], {[1,2,3]=>[1]} )
    assert_eee( +[+[OB.-%:a,OB.-]**+[BR[:a]]], {[1,2]=>[1]} )
    assert_eee( +[+[OB.-%:a,OB.-]**+[BR[:a]]], {[1]=>[1]} )
    assert_eee( +[+[OB.-%:a,OB.-]**+[BR[:a]]], {[1]=>[]} )

    assert_ene( +[+[OB.-,OB.-%:a]**+[BR[:a]]], {[3,2,1]=>[1]} )
    assert_eee( +[+[OB.-,OB.-%:a]**+[BR[:a]]], {[2,1]=>[1]} )
    assert_eee( +[+[OB.-,OB.-%:a]**+[BR[:a]]], {[1]=>[1]} )
    assert_eee( +[+[OB.-,OB.-%:a]**+[BR[:a]]], {[1]=>[]} )

    assert_eee( +[+[OB*(1..2)%:a,OB*(1..2)]**+[BR[:a]]], {[1,1,1]=>[1]} )
    assert_eee( +[+[OB*(1..2)%:a,OB*(1..2)]**+[BR[:a]]], {[1,1,1]=>[1,1]} )
    assert_eee( +[+[OB*(1..2),OB*(1..2)%:a]**+[BR[:a]]], {[1,1,1]=>[1]} )
    assert_eee( +[+[OB*(1..2),OB*(1..2)%:a]**+[BR[:a]]], {[1,1,1]=>[1,1]} )
  end
   

  def test_object_matcher2
    om=-{:f=>1,   /^[gh]+$/=>3..4,   :@v=>/=[a-z]+$/}
     
     eval %{  #use eval to avoid error adding with class inside def
        class Example
          attr_reader *%w{f g h v}
          def initialize(f,g,h,v)
            @f,@g,@h,@v=f,g,h,v
          end
        end
     }
     
     assert_eee om, Example.new(1,3,4,"foo=bar")
     assert_eee om, Example.new(1,4,3,"foo=bar")

     assert_ene om, Example.new(2,3,4,"foo=bar")
     assert_ene om, Example.new(1,33,4,"foo=bar")
     assert_ene om, Example.new(1,3,44,"foo=bar")
     assert_ene om, Example.new(1,3,4,"foo=BAR")
 
   end
   
   
   
   def test_constructors_create_right_syntax_nodes
     #most of the examples use the longer, tla form for the outermost reg....
     #to avoid warnigns without (). anyway, here are the basic equivalences between the
     #operator, tla, and long forms or Reg. 
     #operator form
     assert_eee Reg::Array, +[]
     assert_eee Reg::Subseq, -[]
     assert_eee Reg::Hash, +{}
     assert_eee Reg::Object, -{}

     #tla form (square and round brackets)
     assert_eee Reg::Array, Reg[]
     assert_eee Reg::Subseq, Res[]
     assert_eee Reg::Hash, Rah[]
     assert_eee Reg::Object, Rob[]

     assert_eee Reg::Array, Reg()
     assert_eee Reg::Subseq, Res()
     assert_eee Reg::Hash, Rah()
     assert_eee Reg::Object, Rob()
     
     assert_eee Reg::Or, /a/|/b/
     assert_eee Reg::And, /a/&/b/
     assert_eee Reg::Xor, /a/^/b/

   end
   
   
   def test_OBS_guts
if defined? $MMATCH_PROGRESS #cvt to cmatch someday
     data=[1]
     r=1.reg.*
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==1
     assert ms.next_match(data,0).last==0
     assert ms.next_match(data,0)==nil

     data=[1]
     r=-[nil.reg.-]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==0
     assert ms.next_match(data,0)==nil

     data=[1]
     r=-[nil]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.nil?

     data=[1]
     r=-[1.reg.-,nil]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.nil?

     data=[1]
     r=-[1.reg.*,nil]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.nil?

     data=[1]
     r=-[OBS,nil]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.nil?

     data=[1]
     r=-[-[OBS,nil]|1]
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==1
     assert ms.next_match(data,0)==nil
end
  end

  def try_OBS(exp=+[1,2,3])
   [
    [1,2,3],
    [nil,nil,nil,1,2,3,nil,nil,nil],
    [1,2,3,nil,nil,nil],
    [nil,nil,nil,1,2,3]
   ].map{|data| exp===data ? true : false }
  end

  def test_OBS
    assert_eee( +[], [] )
    assert_eee( +[1.reg.-,1], [1] )
    assert_eee( +[1.reg-2,1], [1,1] )
    assert_eee( +[1.reg.*,1], [1,1] )
    assert_eee( +[OBS], [] )
    assert_eee( +[-[]], [] )
    check_matcher(
      [ +[OBS], ], 
      :matches=>[[],[1],[2],["1"]], :unmatches=>[{},1,:foo,nil,proc{}]
    )
    check_matcher(
      [  +[1,OBS], +[1.reg.*,1], +[OBS,1], +[OBS,OBS,1], +[OBS,OBS,OBS,1] ], 
      :matches=>[[1],[1,1]], :unmatches=>[[2],["1"],[]]
    )
    check_matcher(
      [   +[OBS|1] ], 
      :matches=>[[1],[2],["1"],[],[1,1]]
    )
    
    
    assert_ene(+[OBS,3], [3,nil,nil,nil]) 
    assert_ene(+[1,2,OBS,3], [1,2,3,nil,nil,nil])  #delete this once it works again
    assert_eee try_OBS, [true,false,false,false]
    assert_eee try_OBS(+[1,2,3,OBS]), [true,false,true,false]
    assert_eee try_OBS(+[1,2,OBS,3]), [true,false,false,false]
    assert_eee try_OBS(+[1,OBS,2,3]), [true,false,false,false]
    assert_eee try_OBS(+[OBS,1,2,3]), [true,false,false,true]
    assert_eee try_OBS(+[OBS,1,2,3,OBS]), [true,true,true,true]
    10.times { #seemingly, this one's not deterministic
    check_matcher(
      [ +[nil.reg|1], +[-[OBS,nil]|1] ], 
      :matches=>[[1]], :unmatches=>[[2],["1"],[],[1,1]]
    )
    }
  end
   
  
  
  def test_and
        assert_ene( -[], [] )  
        assert_ene( Reg::And.new(-[]), [] )  
        assert_eee( Reg::And.new(+[]), [] )  
        assert_eee( +[Reg::And.new(-[])], [] )  
    10.times { assert_ene( +[-[]&1], [] )  }
    10.times {  assert_eee( +[-[]&1], [1] )  }
    10.times { 
     assert_eee( +[1.reg&1], [1] ) 
     assert_eee( +[1.reg.-.&1], [1] ) 
     assert_eee( +[1.reg.*.&1], [1] ) 
     assert_eee( +[1.reg.+.&1], [1] ) 
     assert_eee( +[OB&1], [1] ) 
     assert_eee( +[OBS&1], [1] ) 
     assert_eee( +[OBS&1], [1,1] ) 
    }
  
    assert_equal +[OB&(-[])],[]
    assert_equal +[OB&(-[])],nil
    check_matcher(
      [  +[OBS&1] ], 
      :matches=>[[1],[1,1],[1,2]], :unmatches=>[[2],["1"],[]]
    )
    
    
    
  end
   
  
  def test_reg
#     assert_eee( +[OB-1+1]===[1] ) #the 0*infinity problem  #not working
#     assert_eee( +[OB-1-2+1]===[1,2] ) #the 0*infinity problem  #not working


     assert_eee( +[], [] )
     assert_eee( +[1], [1] )
          
     assert_eee( +[ 1.reg.-],   [] )
     assert_eee( +[ 1.reg.-, 3],   [3] )
     assert_eee( +[ 1.reg.-, 3],   [1,3] ) #is the world flat?
     assert_ene( +[ 1.reg.-, 3],   [1,4] ) #is the world flat?
     assert_eee( +[ 1.reg.-, 1],   [1]  )

     assert_eee( +[-[ 1.reg.-,3]],   [1,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-,3]],   [1,4] ) #is the world flat?
     assert_eee( +[-[ 1.reg.-, 2.reg.-], 3],   [1,2,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-, 2.reg.-], 3],   [1,2,4] ) #is the world flat?
     assert_eee( +[ 1.reg.-, 2.reg-2, 3],   [1,2,2,3] ) #is the world flat?
     assert_ene( +[ 1.reg.-, 2.reg-2, 3],   [1,2,2,4] ) #is the world flat?
     assert_eee( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,2,3] ) #is the world flat?
     assert_ene( +[-[2.reg*2], 3],   [2,2,4] ) #is the world flat?
#$RegTraceEnable=1 #debugging zone:
#require 'reginstrumentation'
     assert_ene Reg[-[OB,OB]*(1..2)], [:foo]*3 
     assert_ene Reg[-[OB*2]*(1..2)], [:foo]*3 
     assert_eee Reg[-[OB+2]*(1..2)], [:foo]*3 
     assert_eee Reg[-[OB-2]*(1..2)], [:foo]*3 
     assert_ene( +[-[2.reg-2], 3.reg],   [2,2,4] ) #is the world flat?
     assert_eee( +[-[2.reg-2], 3],   [2,2,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,2,4] ) #is the world flat?
     assert_eee( +[0,-[ 1.reg.-, 2.reg-2], 3],   [0,1,2,2,3] ) #is the world flat?
     assert_ene( +[0,-[ 1.reg.-, 2.reg-2], 3],   [0,1,2,2,4] ) #is the world flat?
     assert_eee( +[0,-[ 1.reg.-, 2.reg-2], 3],   [0,1,2,3] ) #is the world flat?
     assert_ene( +[0,-[ 1.reg.-, 2.reg-2], 3],   [0,1,2,4] ) #is the world flat?
     assert_eee( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,4] ) #is the world flat?
     
     assert_eee( +[1.reg.+, 1], [1,1] )

#...someday convert to use cmatch in these tests
if defined? $MMATCH_PROGRESS     
     data=[:foo]*2
     r=(OB)*(1..2)
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==2
     assert ms.next_match(data,0).last==1
     assert ms.next_match(data,0)==nil

     data=[:foo]*2
     r=(OB*1)*(1..2)
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==2
     assert ms.next_match(data,0).last==1
     assert ms.next_match(data,0)==nil

     data=[:foo]*3
     r=(OB*1)*(1..3)
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==3
     assert ms.next_match(data,0).last==2
     assert ms.next_match(data,0).last==1
     assert ms.next_match(data,0)==nil

     data=[:foo]*4
     r=(OB*2)*(1..2)
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==4
     assert ms.next_match(data,0).last==2
     assert ms.next_match(data,0)==nil

     data=[:foo]*6
     r=(OB*2)*(1..2)*2
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==6
     assert ms.next_match(data,0).last==6
     assert ms.next_match(data,0).last==4
     assert ms.next_match(data,0)==nil

     data=[:foo]*7
     r=(OB*2)*(1..2)*2
     pr=Reg::Progress.new(-[Symbol,r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==7
     assert ms.next_match(data,0).last==7
     assert ms.next_match(data,0).last==5
     assert ms.next_match(data,0)==nil

     data=[:foo]*7
     r=-[(OB*2)*(1..2),(OB*2)*(1..2)]
     pr=Reg::Progress.new(-[Symbol,r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0).last==7
     assert ms.next_match(data,0).last==7
     assert ms.next_match(data,0).last==5
     assert ms.next_match(data,0)==nil

     data=[:foo]*7
     r=(OB*2)*(1..2)*2
     pr=Reg::Progress(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.nil?

     data=[:foo]*8
     r=(OB*2)*(1..2)*2
     pr=Reg::Progress.new(+[r],data.to_sequence)
     ms=r.mmatch(pr)
     assert ms.next_match(data,0)==8
     assert ms.next_match(data,0)==6
     assert ms.next_match(data,0)==6
     assert ms.next_match(data,0)==4
     assert ms.next_match(data,0)==nil
$RegTraceEnable=false#end debug zone
end


 


     assert_eee( +[ item_that.size], ["b"] )



     assert_eee Reg[OB*(1..2)], [:foo]*2
     assert_eee Reg[OB.*(1..2).l], [:foo]*2

     assert_eee( +[-[ 1.reg.-], 3],   [1,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-], 3],   [1,4] ) #is the world flat?
     assert_eee( +[-[ 1.reg.-, 2.reg.-], 3],   [1,2,3] ) #is the world flat?
$RegTraceEnable=1 #debugging zone:
#require 'reginstrumentation'
     assert_ene( +[-[ 1.reg.-, 2.reg.-], 3.reg],   [1,2,4] ) #is the world flat?
     assert_eee( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,2,3] ) #is the world flat?
     assert_ene( +[-[ 1.reg.-, 2.reg-2], 3],   [1,2,2,4] ) #is the world flat?

#disabled til lazy matchers are invented
#    assert_eee Reg[(OB*(1..2)).l*2], [:foo]*4 

     assert_eee Reg[-[OB]], [:foo]*1
     assert_eee Reg[-[OB]*(1..2)], [:foo]*1 
     assert_eee Reg[-[OB]*(1..2)], [:foo]*2 
     assert_eee Reg[-[OB,OB]*(1..2)], [:foo]*2 
     assert_ene Reg[-[OB,OB]*(1..2)], [:foo]*3 
     assert_eee Reg[-[OB,OB]*(1..2)], [:foo]*4
     
     assert_eee Reg[OB*2*(1..2)], [:foo]*2
     assert_ene Reg[OB*2*(1..2)], [:foo]*3
     assert_eee Reg[OB*2*(1..2)], [:foo]*4

     
     assert_eee( +[Set[1,2,3]], [1] )
     assert_eee( +[Set[1,2,3]], [2] )
     assert_ene( +[Set[1,2,3]], [4] )
     
     assert case Set[1,2,3]
            when Set[1,2,3]: true
            end
            
     assert [Set[1,2,3]].grep Set[1,2,3]
     assert !([1].grep Set[1,2,3] ).first
     assert !([2].grep Set[1,2,3] ).first
     assert !([3].grep Set[1,2,3] ).first
     assert_eee( +[-[:foo, :foo]|-[:foo, :foo, :foo, :foo]], [:foo]*4 )
     assert_eee( +[-[:foo, :foo, :foo, :foo]|-[:foo, :foo]], [:foo]*4 )
     assert_eee( +[:foo.reg*2|:foo.reg*4], [:foo]*4 )
     assert_eee( +[:foo.reg*4|:foo.reg*2], [:foo]*4 )

     assert_eee( +[-[:foo, :foo]|-[:foo, :foo, :foo, :foo]], [:foo]*2 )
     assert_eee( +[-[:foo, :foo, :foo, :foo]|-[:foo, :foo]], [:foo]*2 )
     assert_eee( +[:foo.reg*2|:foo.reg*4], [:foo]*2 )
     assert_eee( +[:foo.reg*4|:foo.reg*2], [:foo]*2     )

     assert_eee Reg[(OB*2)*(1..2)*2, (OB*2)], [:foo]*6
     assert_eee Reg[(OB+2)*(1..2)+2, OB+2], [:foo]*6

     assert_eee Reg[-[(OB*2)*(1..2),(OB*2)*(1..2)], (OB*2)], [:foo]*6
     assert_eee Reg[(OB*2)*(1..2),(OB*2)*(1..2), (OB*2)], [:foo]*6

     assert_eee Reg[OB+1,OB+6], [:foo]*7
     assert_eee Reg[OB+1,OB+26], [:foo]*27
     assert_eee Reg[OB*(1..20),OB+7], [:foo]*27
     assert_eee Reg[OB*(1..40),OB+7], [:foo]*27
     assert_eee Reg[OB+6,OB+1], [:foo]*7
     assert_eee Reg[OB+1,OB+1,OB+1], [:foo]*3



     assert_eee(  +[], []  )
     assert_ene(  +[], [:q]  )
     assert_eee(  +[:q], [:q]  )
     assert_eee(  +[-[]], []  )
     assert_eee(  +[-[-[]]], []  )
     assert_ene(  +[-[Reg::Xor[]]], []  )
     assert_ene(  +[-[Reg::And[]]], []  )
     assert_ene(  +[-[Reg::Or[]]], []  )
     assert_eee(  +[//*0], []  )
     assert_eee(  +[-[//*0]], []  )
     assert_eee(  +[-[//-0]], []  )
     assert_eee(  +[-[:q]], [:q]  )
     assert_eee(  +[-[:q]*1], [:q]  )
     assert_eee(  +[-[:q, :q]*1], [:q,:q]  )
     assert_eee(  +[-[:q, :q]*(0..1)], [:q,:q]  )
     assert_eee(  +[-[:q, :q]*(0..2)], [:q,:q]  )
     assert_eee(  +[-[:q, :q]*(0..4)], [:q,:q]  )
     assert_eee(  +[-[:q, :q]*(0..10)], [:q,:q]  )
     assert_eee(  +[-[:q, :q]-1], [:q,:q]  )
     assert_eee(  +[:q.reg+1], [:q]  )
     assert_eee(  +[/q/+1], ['q']  )
     assert_eee(  +[-[:q]+1], [:q]  )
     assert_eee(  +[-[:q, :q]+1], [:q,:q]  )
     assert_eee(  +[-[:q, :q]+0], [:q,:q]  )
     
     


     lenheadalts=-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3]|-[4,OB*4]
     lenheadlist=lenheadalts+1

     lenheaddata=[0,0,0,1,:foo,4,:foo,:bar,:baz,:zork,3,:k,77,88]
     lenheaddataj=lenheaddata+[:j]

     lentailalts=-[OB,-1]|-[OB*2,-2]|-[OB*3,-3]|-[OB*4,-4]
     lentaildata=lenheaddata.reverse.map {|x| Integer===x ? -x : x }
     infixalts=-[OB,"infix1",OB]|-[OB*2,'infix2',OB*2]|
               -[OB*3,'infix3',OB*3]|-[OB*4,'infix4',OB*4]


     qq=-[:q, ~(:q.reg)+0, :q]
     _QQ=-[:Q, ( ~/^[Q\\]$/.sym | -[:'\\',OB] )+0, :Q]

     be=begin_end_pattern :+, 0

     lh_or_qq=lenheadalts|qq|_QQ
     lhqqbe=lh_or_qq|be



     assert_eee(  +[qq*1], [:q,:q]  )
     assert_eee(  +[qq+0], [:q,:q]  )

     assert_eee(  +_QQ, [:Q,:Q]  )
     assert_eee(  +[_QQ], [:Q,:Q]  )
     assert_eee(  +[_QQ*1], [:Q,:Q]  )
     assert_eee(  +[_QQ+0], [:Q,:Q]  )

     assert_eee ::Reg::var.set!(+[1]), [1]
     
     assert_eee(  +[be], [:begin,:end]  )
     assert_eee(  +[be*1], [:begin,:end]  )
     assert_eee(  +[be+0], [:begin,:end]  )
     assert_eee(  +[be+0], [:begin,:end,:begin,:end]  )


     assert_eee(  +[], []  )
     assert_ene(  +[], [1]  )
     assert_eee(  +[-[]], []  )
     assert_ene(  +[-[]], [1]  )
     

     assert_ene Reg[-[:foo,:bar]-1], [:bar,:foo]
     assert_ene Reg[-[:foo,:bar]-1], [:baz,:foo,:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:foo,:bar,:baz]
     assert_eee Reg[-[:foo,:bar]-1], [:foo,:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:foo]
     assert_ene Reg[-[:foo,:bar]-1], [:bar]
     assert_ene Reg[-[:foo,:bar]-1], [:baz]
     assert_eee Reg[-[:foo,:bar]-1], []



     assert_eee Reg[OB.+], [1]
     assert_eee Reg[OB.+], [1,2,3]
     assert_eee Reg[OB.-], [1]
     assert_ene Reg[OB.-], [1,2,3]
     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [1, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [:b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-1, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b]



if defined? NextMatchTests
     a=[:foo]
     x=(:foo.reg-1).mmatch a,0
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==[[[]],0]
     assert x.next_match(a,0)==nil
     x=(:foo.reg-1).mmatch a,1
     assert x==[[[]],0]

     a=[:foo]
     x=(:foo.reg-1-1).mmatch a,0
     assert x.next_match(a,0)==[[[[:foo]]],1]
     assert x.next_match(a,0)==[[[]],0]
     assert x.next_match(a,0)==nil


   


 
     a=(1..5).to_a
     r=OB+1+3
     x=r.mmatch a,0
     assert x.next_match(a,0)==[[ [[1, 2, 3]], [[4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1, 2]], [[3, 4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1, 2]], [[3]], [[4, 5]] ], 5]
     assert x.next_match(a,0)==[[ [[1, 2]], [[3]], [[4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1, 2]], [[3]], [[4]] ], 4]
     assert x.next_match(a,0)==[[ [[1]], [[2, 3, 4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2, 3]], [[4, 5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2, 3]], [[4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2, 3]], [[4]] ], 4]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3, 4, 5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3, 4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3, 4]] ], 4]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3]], [[4, 5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3]], [[4]], [[5]] ], 5]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3]], [[4]] ], 4]
     assert x.next_match(a,0)==[[ [[1]], [[2]], [[3]]], 3]
     assert x.next_match(a,0)==nil

end


     assert_ene Reg[OB+1+2+2], [:f]*3
     assert_ene Reg[OB+2+1+2], [:f]*3
     assert_eee Reg[OB+1+2+2], [:f]*4
     assert_eee Reg[OB+2+2+1], [:f]*4
     assert_eee Reg[OB+2+1+2], [:f]*4
     assert_ene Reg[OB+2+2+2], [:f]*7
     assert_eee Reg[OB+2+2+2], [:f]*8




     assert_ene Reg[OB+2+2+3], [:f]*11
     assert_eee Reg[OB+2+2+3], [:f]*12
     assert_eee Reg[OB+2+2+3], [:f]*16

     assert_ene Reg[5.reg+1+3+2], [6]+[5]*5
     assert_ene Reg[5.reg+1+3+2], [5]+[6]+[5]*4
     assert_ene Reg[5.reg+1+3+2], [5]*2+[6]+[5]*3
     assert_ene Reg[5.reg+1+3+2], [5]*3+[6]+[5]*2
     assert_ene Reg[5.reg+1+3+2], [5]*4+[6,5]
     assert_ene Reg[5.reg+1+3+2], [5]*5+[6]

     assert_eee Reg[OB+1+3+2], [6]+[5]*5
     assert_eee Reg[OB+1+3+2], [5]+[6]+[5]*4
     assert_eee Reg[OB+1+3+2], [5]*2+[6]+[5]*3
     assert_eee Reg[OB+1+3+2], [5]*3+[6]+[5]*2
     assert_eee Reg[OB+1+3+2], [5]*4+[6,5]
     assert_eee Reg[OB+1+3+2], [5]*5+[6]

     assert_ene Reg[OB+1+3+2], [6]+[5]*4
     assert_ene Reg[OB+1+3+2], [5]+[6]+[5]*3
     assert_ene Reg[OB+1+3+2], [5]*2+[6]+[5]*2
     assert_ene Reg[OB+1+3+2], [5]*3+[6]+[5]
     assert_ene Reg[OB+1+3+2], [5]*4+[6]


     assert_eee Reg[5.reg+1+3+2], [5]*6
     assert_ene Reg[5.reg+2+2+2], [5]*8+[6]
     assert_ene Reg[:foo.reg*(1..2)*2*2], 0
     assert_ene Reg[:foo.reg*1], []
     assert_ene Reg[:foo.reg*2], []
     assert_ene Reg[:foo.reg*(1)*2], []

     assert_ene Reg[OB*(1..2)], []
     assert_ene Reg[Symbol*(1..2)], []
     assert_ene Reg[:foo.reg*(1..2)], []
     assert_ene Reg[:foo.reg*(1..2)*2], []
     assert_ene Reg[:foo.reg*(1..2)*2*2], []
     assert_ene Reg[:foo.reg*(1..2)*2*2], [:foo]
     assert_ene Reg[:foo.reg*(1..2)*2*2], [:foo]*2
     assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)], [:foo]*2
     assert_ene Reg[:foo.reg*(1..2)*2*2], [:foo]*3
     assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)], [:foo]*3
     assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)], [:foo]*7
     assert_ene Reg[:foo.reg*(1)*(2)*(2)*(2)], [:foo]*7
     assert_eee Reg[:foo.reg*(1)*(2)*(2)*(2)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2)], [:foo]*2
     assert_eee Reg[:foo.reg*(1..2)*(3)], [:foo]*3
     assert_eee Reg[:foo.reg*(1..2)*(5)], [:foo]*5
     assert_eee Reg[:foo.reg*(1..2)*(8)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2)*(2)*(2)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2)*(2)*(2..3)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2)*(2..3)*(2)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2)*(2..3)*(2..3)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2)*(2..3)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2)], [:foo]*8
     assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)], [:foo]*8

     #too slow
     #assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*15
     #assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*16
     #assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*100

     #cause stack overflows
     #assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*160
     #assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*161
     #assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*162
     #assert_ene Reg[:foo.reg*(1..2)*(2..3)*(2..3)*(2..3)*(2..3)], [:foo]*163

     assert_eee Reg[:foo.reg*(1..2)*(2..3)*(2..3)], [:foo]*4
     assert_ene Reg[OB*(1..2)*(2..3)*(2..3)], [:foo]*3
     assert_eee Reg[OB*(1..2)*(2..3)*(2..3)], [:foo]*4
     assert_ene Reg[OB*(1..2)*(2..3)+2], [:foo]*3
     assert_eee Reg[OB*(1..2)*(2..3)+2], [:foo]*4
     assert_ene Reg[OB+1+2+2], [:foo]*3
     assert_eee Reg[OB+1+2+2], [:foo]*4

     assert_eee Reg[OB*(1..3)*(2..3)*2], [:foo]*4


if defined? NextMatchTests

     a=[:foo]*6
     x=(OB*2*(1..2)*2).mmatch(a,0)
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]], [[:foo, :foo]]], [[[:foo, :foo]]] ], 6]
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]]], [[[:foo, :foo]], [[:foo, :foo]]] ], 6]
     assert x.next_match(a,0)==
       [[ [[[:foo, :foo]]], [[[:foo, :foo]]] ], 4]
     assert x.next_match(a,0).nil?
end

#$RegTraceEnable=true
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2,OB,OB], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2,OB*2], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2,OB+2], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2, OB-1], [:foo]*6
     assert_eee Reg[OB*2*(1..2)*2, OB-1], [:foo]*7
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*8
     assert_eee Reg[OB*2*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*(2..3)*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*(2..3)*(2..3)*(1..2)], [:foo]*4
     assert_eee Reg[OB*(2..2)*(2..3)*(2..3)], [:foo]*8
     assert_eee Reg[OB*(2..3)*(2..2)*(2..3)], [:foo]*8

     assert_eee Reg[OB*(2..3)*(2..3)*2], [:foo]*8
     assert_eee Reg[OB*(2..3)*(2..3)*(2..3)], [:foo]*8
     assert_ene Reg[:foo.reg*(2..3)*(2..3)*2], [:foo]*7

if defined? NextMatchTests
     assert(!(Reg[OB*1*(1..2)]===[:f]).first.empty?)


     a=[:foo]*4
     x=(OB*(1..2)+2).mmatch(a,0)
     assert x.next_match(a,0)==[[ [[:foo, :foo]], [[:foo, :foo]] ], 4]
     assert x.next_match(a,0)==[[ [[:foo, :foo]], [[:foo]], [[:foo]] ], 4]
     assert x.next_match(a,0)==[[ [[:foo, :foo]], [[:foo]] ], 3]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo, :foo]], [[:foo]] ], 4]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo, :foo]] ], 3]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo]], [[:foo, :foo]] ], 4]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo]], [[:foo]], [[:foo]] ], 4]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo]], [[:foo]] ], 3]
     assert x.next_match(a,0)==[[ [[:foo]], [[:foo]] ], 2]
     assert x.next_match(a,0)==nil
end
     assert_ene Reg[OB*(1..2)+2+2], [:foo]*3
     assert_eee Reg[OB*(1..2)+2+2], [:foo]*4

if defined? NextMatchTests

     a=(1..9).to_a
     x=(OB+2+2+2).mmatch a,0
     assert x.next_match(a,0)===[[ [[[1, 2, 3]], [[4, 5]]], [[[6, 7]], [[8, 9]]] ], 9]
     assert x.next_match(a,0)===[[ [[[1, 2]], [[3, 4, 5]]], [[[6, 7]], [[8, 9]]] ], 9]
     assert x.next_match(a,0)===[[ [[[1, 2]], [[3, 4]]], [[[5, 6, 7]], [[8, 9]]] ], 9]
     assert x.next_match(a,0)===[[ [[[1, 2]], [[3, 4]]], [[[5, 6]], [[7, 8, 9]]] ], 9]
     assert x.next_match(a,0)===[[ [[[1, 2]], [[3, 4]]], [[[5, 6]], [[7, 8]]]    ], 8]
     assert x.next_match(a,0)===nil
end

     assert_eee Reg[OB+2+2+2], [:foo]*8
     assert_eee Reg[OB+2+2+2, OB], [:foo]*9
     assert_eee Reg[OB+2+2+2, OB+1], [:foo]*9
     assert_eee Reg[OB+2+2+2, OB-1], [:foo]*9
     assert_eee Reg[OB+2+2+2], [:foo]*9

if defined? NextMatchTests
     a=[:foo]*4
     x=(OB*2*(1..2)).mmatch(a,2)
     assert x.next_match(a,2)==[[[[:foo, :foo]]], 2]
     assert x.next_match(a,2)==nil
end

     assert_eee( +[OB*(1..2)*2],[:foo]*2)

if defined? NextMatchTests
     a=[:foo]*3
     x=(OB*(1..2)*2).mmatch(a,0)
     assert x.next_match(a,0)==
       [[ [[:foo, :foo]], [[:foo]] ], 3]
     assert x.next_match(a,0)==
       [[ [[:foo]], [[:foo, :foo]] ], 3]
     assert x.next_match(a,0)==
       [[ [[:foo]], [[:foo]] ], 2]
     assert x.next_match(a,0).nil?
end

     assert_ene Reg[OB*(2..2)*(2..3)*(2..3)], [:foo]*7
     assert_ene Reg[OB*(2..3)*(2..2)*(2..3)], [:foo]*7
     assert_ene Reg[OB*(1..3)*(2..3)*2], [:foo]*3
     assert_ene Reg[OB*(2..3)*(1..3)*2], [:foo]*3
     assert_ene Reg[OB*(2..3)*(2..3)*(1..2)], [:foo]*3

     assert_ene Reg[OB*(2..3)*(2..3)*2], [:foo]*7
     assert_ene Reg[OB*(2..3)*(2..3)*(2..3)], [:foo]*7
     assert_ene Reg[OB+2+2+2], [:foo]*7


     assert_eee Reg[OB*2*1*2], [:foo]*4
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*2
     assert_eee Reg[OB*2*(1..2)*1], [:foo]*2
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*3
     assert_ene Reg[OB*2*(1..2)*1], [:foo]*3
     assert_eee Reg[OB*1*(1..2)*2], [:foo]*4
     assert_eee Reg[OB*2*(1..2)*1], [:foo]*4


if defined? NextMatchTests

     a=[:foo]*3
     x=(:foo.reg*(1..2)).mmatch a,0
     assert x.next_match(a,0)==[[[:foo]*2],2]
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)).mmatch a,1
     assert x.next_match(a,0)==[[[:foo]*2],2]
     assert x.next_match(a,0)==[[[:foo]],1]
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)).mmatch a,2
     assert x==[[[:foo]],1]

     x=(:foo.reg*(1..2)).mmatch a,3
     assert x.nil?

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,0
     assert x.next_match(a,0)==[[[[:foo]*2],[[:foo]]], 3]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]*2]], 3]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]],[[:foo]]], 3]
     assert x.instance_eval{@ri}==3
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]]], 2]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,1
     assert x.next_match(a,0)==[[[[:foo]],[[:foo]]], 2]
     assert x.instance_eval{@ri}==2
     assert x.next_match(a,0)==nil

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,2
     assert x.nil?

     x=(:foo.reg*(1..2)*(2..3)).mmatch a,3
     assert x.nil?

     assert((not (:foo.reg*(1..2)*(2..3)*(2..3)).mmatch [:foo]*3,0 ))
end




     assert_eee Reg[5.reg+2+2], [5]*4
     assert_eee Reg[5.reg*(1..2)*(1..2)*(1..2)], [5]
     assert_eee Reg[5.reg*(1..2)*(1..2)*(2..3)], [5]*2
     assert_eee Reg[5.reg*(1..2)*(2..3)*(2..3)], [5]*4
     assert_eee Reg[(5.reg+1)*(2..3)*(2..3)], [5]*4
     assert_eee Reg[(5.reg+1+2)*(2..3)], [5]*4
     assert_eee Reg[5.reg+1+2+2], [5]*4
     assert_eee Reg[OB+3+2], [:f]*6

     #stack overflow
     #aaa_patho=-[/^a/]|-[/^.a/, OB]|-[/^..a/, OB*2]
     #assert_ene(  +[aaa_patho], ["aaa"]*200  )
     #assert_eee(  +[aaa_patho+0], ["aaa"]*200  )




     assert_eee Reg[(-[-[:p]*(1..2)])], [:p]
     assert_eee Reg[(-[-[:p]*(1..2)])], [:p,:p]
     assert_ene Reg[(-[-[:p]*(1..2)])], [:p,:q]
     assert_ene Reg[(-[-[:p]*(1..2)])], [:q]
     assert_ene Reg[(-[-[:p]*(1..2)])], []
     assert_ene Reg[(-[-[:p]*(1..2)])], [:p,:p, :p]


     assert_eee Reg[OB+1], [:foo,:foo]
     assert_eee Reg[OB+1+1], [:foo,:foo]
     assert_eee Reg[OB+1+1+1], [:foo,:foo]
     assert_eee Reg[OB+1+1+1+1], [:foo,:foo]

     assert_ene Reg[OB+2+3], [:f]*5
     assert_ene Reg[OB+2+2+1], [:f]*3
   end
   
   def test_recursive_vector_pattern
     lenheadalts=-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3]|-[4,OB*4]
     lenheadlist=lenheadalts+1

     lenheaddata=[0,0,0,1,:foo,4,:foo,:bar,:baz,:zork,3,:k,77,88]
     lenheaddataj=lenheaddata+[:j]

     lentailalts=-[OB,-1]|-[OB*2,-2]|-[OB*3,-3]|-[OB*4,-4]
     lentaildata=lenheaddata.reverse.map {|x| Integer===x ? -x : x }
     infixalts=-[OB,"infix1",OB]|-[OB*2,'infix2',OB*2]|
               -[OB*3,'infix3',OB*3]|-[OB*4,'infix4',OB*4]


     qq=-[:q, ~(:q.reg)+0, :q]
     _QQ=-[:Q, ( ~/^[Q\\]$/.sym | -[:'\\',OB] )+0, :Q]

     be=begin_end_pattern :+, 0

     lh_or_qq=lenheadalts|qq|_QQ
     lhqqbe=lh_or_qq|be

     assert_eee(+[be], [
                          :begin, :SubseqMatchSet, :IndexError, :termsig, :"\\", :ll,
                          :end]
     )
     assert_eee(+[be+0], [
                          :begin, :SubseqMatchSet, :IndexError, :termsig, :"\\", :begin,
                          :end]
     )
     assert_eee(+[be+0], [
                          :begin, :SubseqMatchSet, :IndexError, :termsig, :"\\", :end,
                          :end]
     )
     assert_eee(+[be+0], [
                          :begin, :SubseqMatchSet, :IndexError, :termsig, :"\\", 
                            :begin, :right, :"\\", 
                              :begin, :f, :call, :safe_level, :"\\", 
                                :begin, :undefine_finalizer, :test_anonymous, :quote, 
                          :end]
     )
     assert_eee(+[lhqqbe+0], [
                          :begin, :SubseqMatchSet, :IndexError, :termsig, :"\\", 
                            :begin, :right, :"\\", 
                              :begin, :f, :call, :safe_level, :"\\", 
                                :begin, :undefine_finalizer, :test_anonymous, :quote, 
                          :end]
     )

     assert_eee Reg[be+0], [
      :begin, :popen, :"chomp!", :-@, :end, #:q, :q,
      :begin, :begin, :end, :end,
      :begin, :MINOR_VERSION, :"public_method_defined?", :"\\", :begin, :umask,
              :debug_print_help, :geteuid, :end,
#      :q, :public_methods, :option_name, :MUTEX, :q,
      :begin, :verbose=, :binding, :symlink, :lambda,
              :emacs_editing_mode, :"dst?", :end, #0,
      :begin, :test_to_s_with_iv, :"\\", :begin, :glob, :each_with_index,
              :initialize_copy, :begin, :$PROGRAM_NAME, :end,
              :ELIBACC, :setruid, :"success?", :end,
      :begin, :__size__, :width, :"\\", :begin, :$-a, :"sort!", :waitpid, :end,
      :begin, :Stat, :WadlerExample, :chr, :end,
      :begin, :+, :disable, :abstract,
              :begin, :__size__, :"symlink?", :"dst?", :end, :ljust, :end,
      :begin, :debug_method_info, :matchary, :"\\", :begin, :ftype,
              :thread_list_all, :eof, :begin, :abs, :GroupQueue, :end,
              :"slice!", :ordering=, :end,
#      :Q, :"\\", :Q, :ELIBMAX, :GetoptLong, :nlink, :Q,
      :begin, :Fixnum, :waitall, :"enclosed?", :"\\", :begin, :deep_copy,
              :getpgid, :strftime, :end,
 #     :Q, :close_obj, :Q,
#      3, :basic_quote_characters=, :rmdir, :"writable_real?",
      :begin, :test_hello_11_12, :utc_offset, :freeze,
              :begin, :kcode, :egid=, :ARGF, :end,
              :setuid, :lock, :gmtoff, :end,
      :begin, :$FILENAME, :test_tree_alt_20_49,
              :begin, :LOCK_SH, :EL3HLT, :end, :end,
#      :Q, :"\\", :Q, :ceil, :remainder, :group_sub, :Q, 0
     ]
     assert_eee Reg[lhqqbe+0], [
      :begin, :popen, :"chomp!", :-@, :end, :q, :q,
      :begin, :begin, :end, :end,
      :begin, :MINOR_VERSION, :"public_method_defined?", :"\\", :begin, :umask,
              :debug_print_help, :geteuid, :end,
      :q, :public_methods, :option_name, :MUTEX, :q,
      :begin, :verbose=, :binding, :symlink, :lambda,
              :emacs_editing_mode, :"dst?", :end, 0,
      :begin, :test_to_s_with_iv, :"\\", :begin, :glob, :each_with_index,
              :initialize_copy, :begin, :$PROGRAM_NAME, :end,
              :ELIBACC, :setruid, :"success?", :end,
      :begin, :__size__, :width, :"\\", :begin, :$-a, :"sort!", :waitpid, :end,
      :begin, :Stat, :WadlerExample, :chr, :end,
      :begin, :+, :disable, :abstract,
              :begin, :__size__, :"symlink?", :"dst?", :end, :ljust, :end,
      :begin, :debug_method_info, :matchary, :"\\", :begin, :ftype,
              :thread_list_all, :eof, :begin, :abs, :GroupQueue, :end,
              :"slice!", :ordering=, :end,
      :Q, :"\\", :Q, :ELIBMAX, :GetoptLong, :nlink, :Q,
      :begin, :Fixnum, :waitall, :"enclosed?", :"\\", :begin, :deep_copy,
              :getpgid, :strftime, :end,
      :Q, :close_obj, :Q,
      3, :basic_quote_characters=, :rmdir, :"writable_real?",
      :begin, :test_hello_11_12, :utc_offset, :freeze,
              :begin, :kcode, :egid=, :ARGF, :end,
              :setuid, :lock, :gmtoff, :end,
      :begin, :$FILENAME, :test_tree_alt_20_49,
              :begin, :LOCK_SH, :EL3HLT, :end, :end,
      :Q, :"\\", :Q, :ceil, :remainder, :group_sub, :Q, 0
     ]
     assert_eee Reg[lhqqbe+0], [ :begin, :"\\", :rand, :end ]
 #breakpoint
     assert_eee( +[be], [:begin, :"\\", :"\\", :end])
     assert_eee( +[be], [:begin, :"\\", :begin, :end])
     assert_eee( +[be], [:begin, :"\\", :end, :end])
     assert_eee( +[be], [:begin, :log, :readline, :"\\", :begin, :lh_or_qq, :test_pretty_print_inspect, :@newline, :end])
     assert_eee( +[be], [:begin, :lock, :rindex, :begin, :sysopen, :rename, :end, :re_exchange, :on, :end])
     assert_eee( +[be], [:begin, :lock, :"\\", :"\\", :begin, :rename, :end, :on, :end])
     assert_eee( +[be], [:begin, :begin, :foo, :end, :end])
     assert_eee( +[be], makelendata(1,0b11110000000).flatten)
     assert_eee( +[be], [:begin, :end])
     assert_eee( +[be], [:begin, :foo, :end])
     assert_eee( +[be], makelendata(1,0b10000000).flatten)
     assert_eee Reg[lhqqbe+0], makelendata(1,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(4,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(10,0b11111110011).flatten
     assert_eee Reg[lhqqbe+0], makelendata(20,0b11111110011).flatten

     assert_eee Reg[lenheadlist], [1, :__id__]
     assert_eee Reg[lenheadlist], [2, :p, :stat]
     assert_eee Reg[lenheadlist], [2, :p, :stat, 1, :__id__]
     assert_eee Reg[lenheadlist], [2, :p, :stat, 0, 1, :__id__, 0, 0]
     assert_eee Reg[lenheadlist], lenheaddata
     assert_ene Reg[lenheadlist], lenheaddataj
     assert_eee( +[lh_or_qq+0], lenheaddata )
     assert_eee( +[lh_or_qq+0], lenheaddata+[:q, :foo, :bar, :baz, :q] )

     assert_eee Reg[lenheadlist], [0]
     assert_eee Reg[lenheadlist], makelendata(1,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(5,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(10,0b11).flatten
     assert_eee Reg[lenheadlist], makelendata(20,0b11).flatten
     assert_ene Reg[lenheadlist], makelendata(20,0b11).flatten+[:j]
     assert_ene Reg[lenheadlist], [:j]+makelendata(20,0b11).flatten+[:j]
     assert_ene Reg[lenheadlist], [:j]+makelendata(20,0b11).flatten

     assert_ene Reg[lenheadlist], makelendata(20,0b11,:j).flatten
     assert_eee( +[lh_or_qq+0], makelendata(20,0b11).flatten )
     assert_eee( +[lh_or_qq+0], makelendata(20,0b1000011).flatten )
     assert_ene( +[lh_or_qq+0], makelendata(20,0b1000011).flatten+[:j] )
     assert_ene( +[lh_or_qq+0], [:j]+makelendata(20,0b1000011).flatten+[:j] )
     assert_ene( +[lh_or_qq+0], [:j]+makelendata(20,0b1000011).flatten )
   end
   if ENV['SLOW']
     def test_slow; disabled_test_slow; end
   else
     warning "slow tests disabled... run with env var SLOW=1 to enable"
   end
   def _; print '_'; $stdout.flush end
   def disabled_test_slow
     #btracing monsters
     _;assert_ene Reg[OB+1+3+2], (1..5).to_a
     0.upto(5) {|i| _;assert_ene Reg[OB+1+3+2], [:f]*i }
     6.upto(16){|i| _;assert_eee Reg[OB+1+3+2], [:f]*i }

     _;assert_ene Reg[OB+2+3+2], [:f]*11
     _;assert_eee Reg[OB+2+3+2], [:f]*12
     _;assert_ene Reg[OB+2+3+3], [:f]*17
     _;assert_eee Reg[OB+2+3+3], [:f]*18
     _;assert_ene Reg[OB+3+3+3], [:f]*26
     _;assert_eee Reg[OB+3+3+3], [:f]*27
#     assert_ene Reg[OB+4+4+4], [:f]*63 #insane
#     assert_eee Reg[OB+4+4+4], [:f]*64 #insane
     _;assert_ene Reg[OB+2+2+2+2], [:f]*15 
     _;assert_eee Reg[OB+2+2+2+2], [:f]*16
#     assert_ene Reg[OB+2+2+2+2+2+2+2+2], [:foo]*255 #insane
#     assert_eee Reg[OB+2+2+2+2+2+2+2+2], [:foo]*256 #insane


     #assert_eee Reg[OB+10+10], [:f]*100 #waaaay too slow
     _;assert_eee Reg[OB+5+5], [:f]*25
     _;assert_ene Reg[OB+5+5], [:f]*24
     _;assert_eee Reg[OB+6+6], [:f]*36
     _;assert_ene Reg[OB+6+6], [:f]*35
     _;assert_eee Reg[OB+7+7], [:f]*49 #prolly excessive
     _;assert_ene Reg[OB+7+7], [:f]*48 #prolly excessive

     _;assert_ene Reg[OB+1+2+2+2], [:f]*7
     _;assert_eee Reg[OB+1+2+2+2], [:f]*8
     _;assert_ene Reg[OB+1+1+2+2+2], [:f]*7
     _;assert_eee Reg[OB+1+1+2+2+2], [:f]*8
     _;assert_ene Reg[OB+1+1+1+2+2+2], [:f]*7
     _;assert_eee Reg[OB+1+1+1+2+2+2], [:f]*8

     _;assert_ene Reg[OB+1+1+1+1+2+2+2], [:f]*7
     _;assert_eee Reg[OB+1+1+1+1+2+2+2], [:f]*8

     r=2..3
     _;assert_ene Reg[OB*(1..2)*r*r*r], [:f]*7
     _;assert_eee Reg[OB*(1..2)*r*r*r], [:f]*8
   end

   def test_reg2
     assert_ene Reg[:foo,OB+1], [:foo]
     assert_ene Reg[OB+1,:foo], [:foo]
     assert_eee Reg[OB+1], [:foo]


     assert_eee Reg[OB+1+1+1+1+1+1+1+1+1+1+1+1+1+1], [:foo]

     assert_ene Reg[OB+1+1+1+1], []
     assert_eee Reg[OB+1+1+1+1], [:foo,:foo]
     assert_ene Reg[OB+2], [:foo]
     assert_ene Reg[OB+2+2], [:foo]*3
     assert_ene Reg[OB+2+2+1], [:foo]*3
     assert_ene Reg[OB+2+1+2], [:foo]*3


     assert_eee Reg[-[1,2]|3], [1,2]
     assert_eee Reg[-[1,2]|3], [3]
     assert_ene Reg[-[1,2]|3], [4]
     assert_ene Reg[-[1,2]|3], [2]
     assert_ene Reg[-[1,2]|3], [1,3]

     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])*1], [2, :p, :stat]
     assert_eee Reg[(-[2,OB*2])-1], [2, :p, :stat]
     assert_eee Reg[(-[OB])*(1..2)], [1, :p]

     assert_eee Reg[(-[-[:p]*(1..2)])], [:p]
     assert_eee Reg[(-[-[:p]])*(1..2)], [:p]
     assert_eee Reg[(-[-[OB]])*(1..2)], [:p]
     assert_eee Reg[(-[OB*1])*(1..2)], [:p]
     assert_eee Reg[(-[1,OB*1])*(1..2)], [1, :p]
     assert_eee Reg[(-[2,OB*2])*(1..2)], [2, :p, :stat]
     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])*(1..2)], [2, :p, :stat]
     assert_eee Reg[(-[0]|-[1,OB]|-[2,OB*2])+1], [2, :p, :stat]
   end

   def test_btracing_monsters
     #btracing monsters:
     assert_eee Reg[OB*2], [:foo]*2
     assert_eee Reg[OB*2*2], [:foo]*4
     assert_eee Reg[OB*2*2*2*2], [:foo]*16
     assert_eee Reg[OB*2*2*2*2*2*2*2*2], [:foo]*256
     assert_eee Reg[OB*2*2*2*2*2*2*2*2*2], [:foo]*512
     assert_eee Reg[OB-2-2-2-2-2], [:foo]*32
     assert_eee Reg[OB-2-2-2-2-2-2], [:foo]*64
     assert_eee Reg[OB-2-2-2-2-2-2-2], [:foo]*128
     assert_eee Reg[OB-2-2-2-2-2-2-2-2], [:foo]*256
   end

   def test_reg3
     t=(1..2)
     assert_eee Reg[OB*t*t*t*t], [:foo]*16
     assert_ene Reg[OB*t*t*t*t], [:foo]*17
     assert_eee Reg[5.reg*t], [5]
     assert_eee Reg[5.reg*t*1], [5]
     assert_eee Reg[5.reg*1*t], [5]
     assert_eee Reg[5.reg*t*t], [5]
     assert_eee Reg[5.reg*t*t*t], [5]
     assert_eee Reg[5.reg*t*t*t*t], [5]
     assert_eee Reg[5.reg+1+1+1], [5]
     assert_eee Reg[5.reg+1+1+1+1], [5]
     assert_eee Reg[OB+1+1+1], [:foo]
     assert_eee Reg[OB+1+1+1+1], [:foo]
     assert_eee Reg[OB+2], [:foo]*2
     assert_eee Reg[OB+2+2], [:foo]*4





     assert_ene Reg[OB-0], [1]
     assert_eee Reg[OB+0], [1]
     assert_eee Reg[OB-1], [1]
     assert_eee Reg[OB+1], [1]
     assert_eee Reg[OB-2], [1,2]
     assert_eee Reg[OB+2], [1,2]

     assert_eee Reg[OB], [1]
     assert_eee Reg[OB*1], [1]
     assert_eee Reg[OB*2], [1,2]
     assert_eee Reg[OB*4], [1,2,3,4]

     abcreg=Reg[OBS,:a,:b,:c,OBS]
     assert_eee abcreg, [:a,:b,:c,7,8,9]
     assert_eee abcreg, [1,2,3,:a,:b,:c,7,8,9]

     assert_eee abcreg, [1,2,3,:a,:b,:c]
     assert_eee abcreg, [:a,:b,:c]

     assert_ene abcreg, [1,2,3,:a,:b,:d]
     assert_ene abcreg, [1,2,3,:a,:d,:c]
     assert_ene abcreg, [1,2,3,:d,:b,:c]

     assert_ene abcreg, [1,2,3]
     assert_ene abcreg, [1,2,3,:a]
     assert_ene abcreg, [1,2,3,:a,:b]

     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+0, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_eee Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB+1, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_ene Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, 1,1,1,1,1,1, :b, :b, :b, :b, :b]
     assert_ene Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, 1, :b, :b, :b, :b, :b]
     assert_eee Reg[:a, OB-0, :b, :b, :b, :b, :b], [:a, :b, :b, :b, :b, :b]

     assert_eee Reg[-[OB*2]], [99, 99]  #di not right in top level
     assert_eee Reg[-[-[-[-[-[OB*2]]]]]], [99, 99]  #di not right in top level?
     assert_eee Reg[-[-[-[-[-[OB*1]]]]]], [99]  #di not right in top level?
     #RR[RR[[RR[RR[RR[RR[99,99]]]]]]]
     assert_eee Reg[OB*1], [:foo]
     assert_eee Reg[-[OB]], [88]
     assert_ene Reg[-[0]], [88]
     assert_eee Reg[-[0]], [0]
     assert_eee Reg[-[OB*1]], [:foo]
     assert_eee Reg[OB*1*1], [:foo]
     assert_eee Reg[OB*1*1*1*1*1*1*1*1*1*1*1*1*1*1], [:foo]
     assert_eee Reg[OB-1-1-1-1-1-1-1-1-1-1-1-1-1-1], [:foo]
     assert_eee Reg[-[2,OB*2]], [2, 99, 99]

#     assert_eee Reg::Multiple, -[0]|-[1,2]
#     assert( (-[0]|-[1,2]).respond_to?( :mmatch))

     lenheaddata=[0,0,0,1,:foo,4,:foo,:bar,:baz,:zork,3,:k,77,88]
     lenheaddataj=lenheaddata+[:j]

     assert_eee Reg[-[0],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3],OBS], lenheaddataj
     assert_eee Reg[-[0]|-[1,OB]|-[2,OB*2]|-[3,OB*3]|-[4,OB*4],OBS], lenheaddataj








#Matches array containing exactly 2 elements; 1st is another array, 2nd is
#integer:
     assert_eee( +[Array,Integer], [["ee"],555])

#Like above, but 1st is array of arrays of symbol
     assert_eee( +[+[+[Symbol+0]+0],Integer], [[[:foo,:bar],[:baz,:bof]], 0])

#Matches array of at least 3 consecutive symbols and nothing else:
     assert_ene( +[Symbol+3], [:hop]*2)
     assert_eee( +[Symbol+3], [:hop]*3)
     assert_eee( +[Symbol+3], [:hop]*4)

#Matches array with at least 3 (consecutive) symbols in it somewhere:
     assert_eee( +[OBS, Symbol+3, OBS], [Module, nil, 1, "o", :g, [66,77], {888=>999}, :a, :b, :c])
     assert_eee( +[OBS, Symbol+3, OBS], [Module, nil, 1, :a, :b, :c, "o", :g, [66,77], {888=>999}])
     assert_ene( +[OBS, Symbol+3, OBS], [Module, nil, 1, :a, :b, "o", :g, [66,77], {888=>999}])
     assert_eee( +[OBS, Symbol+3, OBS], [:a, :b, :c, Module, nil, 1, "o", :g, [66,77], {888=>999}])

#Matches array of at most 6 strings starting with 'g'
     assert_eee( +[/^g/-6], [])
     assert_eee( +[/^g/-6], ["gh"])
     assert_eee( +[/^g/-6], ["gh","gg"])
     assert_eee( +[/^g/-6], ["gh","gg", "gf"])
     assert_eee( +[/^g/-6], ["gh","gg", "gf", "ge"])
     assert_eee( +[/^g/-6], ["gh","gg", "gf", "ge","gd"])
     assert_eee( +[/^g/-6], ["gh","gg", "gf", "ge","gd","gc"])
     assert_ene( +[/^g/-6], ["gh","gg", "gf", "ge","gd","gc","gd"])

#Matches array of between 5 and 9 hashes containing a key :k pointing to
#something non-nil:
     h={:k=>true}
     assert_eee( +h, h)
     assert_eee( +{:k=>OB}, h)
     assert_eee( +{:k=>~nil.reg}, h)
     assert_ene( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h])
     assert_eee( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h])
     assert_eee( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h,h])
     assert_eee( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h,h,h])
     assert_eee( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h,h,h,h])
     assert_eee( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h,h,h,h,h])
     assert_ene( +[ +{:k=>~nil.reg}*(5..9) ], [h,h,h,h,h,h,h,h,h,h])

#Matches an object with Integer instance variable @k and property (ie method)
#foobar that returns a string with 'baz' somewhere in it:
     assert_eee( -{:@k=>Integer}, [].instance_eval{@k=5;self})
    end
    
    def test_anystruct
     assert AnyStruct[:k=>5]
     assert_eee( -{:@k=>Integer}, AnyStruct[:k=>5])
     assert_eee( -{:@k=>Integer}, AnyStruct[:k=>5, :foobar=>"kla-baz"])
     assert_eee( -{:@k=>Integer, :foobar=>/baz/}, AnyStruct[:k=>5, :foobar=>"kla-baz"])
    end


  def test_matcher_more
#Matches array of 6 hashes with 6 as a value of every key, followed by
#18 objects with an attribute @s which is a String:
     check_matcher( +[ +{OB=>6}*6 ], :matches=>[[ {:a=>6},{:a=>6,:b=>6},{:a=>6,:b=>6,:c=>6},{:hodd=>6},
          {:tuber=>6.0}, {:xxx=>6, :e=>6} ]])
     check_matcher( +[ +{OB=>6}*6, -{:@s=>String}*18 ], 
       :matches=>[ [ {:a=>6},{:a=>6,:b=>6},{:a=>6,:b=>6,:c=>6},{:hodd=>6},
                     {:tuber=>6.0}, {:xxx=>6, :e=>6}, *[AnyStruct[:s=>"66"]]*18 ]
                  ],
       :unmatches=>[
         [ {:a=>6},{:a=>6,:b=>6},{:a=>6,:b=>6,:c=>6},{:hodd=>6},
           {:tuber=>6.0}, {:xxx=>6, :e=>6}, *[AnyStruct[:s=>"66"]]*17 ],
         [ {:a=>6},{:a=>6,:b=>6},{:a=>6,:b=>6,:c=>6},{:hodd=>6},
           {:tuber=>6.0}, {:xxx=>6, :e=>6}, *[AnyStruct[:s=>"66"]]*19 ],
         [ {:a=>6},{:a=>5,:b=>6},{:a=>4,:b=>5,:c=>6},{:hodd=>6},
           {:tuber=>6.0}, {:xxx=>"t", :e=>6}, *[AnyStruct[:s=>"66"]]*18 ]
       ]
     )

     check_matcher( +[/fo+/**8, /ba+r/**9], 
       :matches=> [{"foobar"=>8, "bar"=>9},{"foo"=>8,"bar"=>9}],
       :unmatches=> {"foobar"=>9, "bar"=>9})
       


     print "\n"
   end

   def check_variables(data,*rest)
     vals_list=rest.pop
     vars=("a"...(?a+rest.size).chr).to_a
     pat=[]
     rest.each_index{|i| pat<< ((rest[i]+1)%vars[i].to_sym) }
     regpat=+pat
     assert x=regpat.match( data )
     assert regpat.match([]).nil? unless rest.empty?
     vals_list.each_index{|i|
       assert_equal [vals_list[i]] , x[vars[i]]
       assert_equal [vals_list[i]] , x.send(vars[i])
     }
     regpat=+[-[*pat[0..1]],*pat[2..-1]]
     assert x=regpat.match( data)
     assert regpat.match([]).nil? unless rest.empty?
     vals_list.each_index{|i|
       assert_equal [vals_list[i]] , x[vars[i]]
       assert_equal [vals_list[i]] , x.send(vars[i])
     }

     #this way might make warnings...
     pat=[]
     rest.each_index{|i| pat<< (rest[i]%vars[i].to_sym)+1 }
     regpat=+pat
     assert x=regpat.match( data)
     assert regpat.match([]).nil? unless rest.empty?
     vals_list.each_index{|i|
       assert_equal vals_list[i] , x[vars[i]]
       assert_equal vals_list[i] , x.send( vars[i]) 
     }
     regpat=+[-[*pat[0..1]],*pat[2..-1]]
     assert x=regpat.match( data)
     assert regpat.match([]).nil? unless rest.empty?
     vals_list.each_index{|i|
       assert_equal vals_list[i] , x[vars[i]]
       assert_equal vals_list[i] , x.send( vars[i])
     }
   end

   def test_var_bindings
     check_variables([1,2,3],OB,OB,OB,[1,2,3])
     check_variables([1,2,3],OB,OB,OB-1,[1,2,3])
     check_variables([1,2],OB,OB,OB-1,[1,2,nil])
     check_variables([1,2,3],OB,OB+1,OB,[1,2,3])
   end
   
   def test_logic
        assert_eee( /s/^/t/,'siren')
     assert_eee( /s/^/t/,'tire')
     assert_ene( /s/^/t/,'street')
     assert_ene( /s/^/t/,'and')
     
     assert_ene( /s/^/t/^/r/,'siren')
     assert_eee( /s/^/t/^/r/,'sigh')
     assert_ene( /s/^/t/^/r/,'tire')
     assert_eee( /s/^/t/^/r/,'tie')
     assert_eee( /s/^/t/^/r/,'rye')
     assert_ene( /s/^/t/^/r/,'stoop')
     assert_ene( /s/^/t/^/r/,'street')
     assert_ene( /s/^/t/^/r/,'and')

     assert_ene( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "a","b","c", 4,5,6] )
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "soup", 4,5,6] )
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "stoop", 4,5,6] )
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "stoop", "rickshaw", 4,5,6] )#backtracking fools ya
     assert_eee( +[OBS.l, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS.l], 
       [1,2,3, "stoop", "rickshaw", 4,5,6] )#lazy ought to work
     assert_ene( +[-[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/]], ["stoop", "rickshaw"])
     assert_ene( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "sit", "ran", "gee-gaw",4,5,6])
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "turtle", "rickshaw", 4,5,6] )#works, but backtracking fools ya
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "turtle", "rival", 4,5,6] )
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "ink", "nap", "great, super", 4,5,6] )#works, but backtracking fools ya; it was /s/ that matched
     assert_eee( +[OBS, -[/s/]^-[/t/,/r/]^-[/i/,/n/,/g/], OBS], 
       [1,2,3, "ink", "nap", "great", 4,5,6]  )

     assert_eee( /s/|/t/,'siren')
     assert_eee( /s/|/t/,'tire')
     assert_eee( /s/|/t/,'street')
     assert_ene( /s/|/t/,'and')
     
     assert_eee( /s/|/t/|/r/,'siren')
     assert_eee( /s/|/t/|/r/,'sigh')
     assert_eee( /s/|/t/|/r/,'tire')
     assert_eee( /s/|/t/|/r/,'tie')
     assert_eee( /s/|/t/|/r/,'rye')
     assert_eee( /s/|/t/|/r/,'stoop')
     assert_eee( /s/|/t/|/r/,'street')
     assert_ene( /s/|/t/|/r/,'and')

     assert_ene( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "a","b","c", 4,5,6] )
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "soup", 4,5,6] )
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "stoop", 4,5,6] )
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "stoop", "rickshaw", 4,5,6] )
     assert_eee( +[OBS.l, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS.l], 
       [1,2,3, "stoop", "rickshaw", 4,5,6] )
     assert_eee( +[-[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/]], ["stoop", "rickshaw"])
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "sit", "ran", "gee-gaw",4,5,6])
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "turtle", "rickshaw", 4,5,6] )
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "turtle", "rival", 4,5,6] )
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "ink", "nap", "great, super", 4,5,6] )#works, but backtracking fools ya; it was /s/ that matched
     assert_eee( +[OBS, -[/s/]|-[/t/,/r/]|-[/i/,/n/,/g/], OBS], 
       [1,2,3, "ink", "nap", "great", 4,5,6]  )

     assert_ene( /s/&/t/,'siren')
     assert_ene( /s/&/t/,'tire')
     assert_eee( /s/&/t/,'street')
     assert_ene( /s/&/t/,'and')
     
     assert_ene( /s/&/t/&/r/,'siren')
     assert_ene( /s/&/t/&/r/,'sigh')
     assert_ene( /s/&/t/&/r/,'tire')
     assert_ene( /s/&/t/&/r/,'tie')
     assert_ene( /s/&/t/&/r/,'rye')
     assert_ene( /s/&/t/&/r/,'stoop')
     assert_eee( /s/&/t/&/r/,'street')
     assert_ene( /s/&/t/&/r/,'and')

     check_matcher( +[-[/s/]&-[/t/,/r/]&-[/i/,/n/,/g/]], 
       :unmatches=>[["stoop", "rickshaw"],["sit", "ran", "hee-haw"]],
       :matches=>[["sit", "ran", "gee-gaw"],["sting", "range", "great"]]
     )

     check_matcher( 
       [ +[OBS.l, -[/s/]&-[/t/,/r/]&-[/i/,/n/,/g/], OBS.l],
         +[OBS, -[/s/]&-[/t/,/r/]&-[/i/,/n/,/g/], OBS], 
       ], 
       :matches=>[ 
       ["sit", "ran", "gee-gaw"],
       [1,2,3, "sit", "ran", "gee-gaw",4,5,6],
       [1,2,3, "sting", "range", "great", 4,5,6]
       ],
       
       :unmatches=>[ 
       [1,2,3, "a","b","c", 4,5,6],
       [1,2,3, "soup", 4,5,6] ,
       [1,2,3, "stoop", 4,5,6] ,
       [1,2,3, "stoop", "rickshaw", 4,5,6] ,
       [1,2,3, "turtle", "rickshaw", 4,5,6] ,
       [1,2,3, "turtle", "rival", 4,5,6] ,
       [1,2,3, "ink", "nap", "great, super", 4,5,6] ,
       [1,2,3, "ink", "nap", "great", 4,5,6]  
       
       ]
      )
       
     check_matcher( +[-[/a/,/b/,/c/] & (item_that.size < 4) ], 
       :matches=>[["al", "robert", "chuck"]],
       :unmatches=>[["albert", "robert", "chuck"]]
     )
   end
   

 BOARD_MEMBERS = ['Jan', 'Julie', 'Archie', 'Stewick']
 HISTORIANS = ['Braith', 'Dewey', 'Eduardo']
 YAHOOS = ['Mitch','Christian','Dan']
  def test_toplevel_replacement

    assert_equal "You're on the board!  A congratulations is in order.", BOARD_MEMBERS.alter(
        BOARD_MEMBERS.reg>> "You're on the board!  A congratulations is in order."  |
        HISTORIANS.reg>>    "You are busy chronicling every deft play."
        )
    

    assert_equal "You are busy chronicling every deft play.", HISTORIANS.alter(
      BOARD_MEMBERS.reg>> "You're on the board!  A congratulations is in order."  |
      HISTORIANS.reg>>    "You are busy chronicling every deft play."
    )

    assert_nil YAHOOS.alter(
      BOARD_MEMBERS.reg>>
        "You're on the board!  A congratulations is in order."  |
      HISTORIANS.reg>>
        "You are busy chronicling every deft play." 
    )

    for name in BOARD_MEMBERS|HISTORIANS
    assert_eee "You're on the board!  A congratulations is in order.".reg|
               "You are busy chronicling every deft play.", name.alter(
    Set[*BOARD_MEMBERS]>> "You're on the board!  A congratulations is in order."  |
    Set[*HISTORIANS]>> "You are busy chronicling every deft play." 
    )
    end

    for name in YAHOOS
    assert_nil name.alter \
    Set[*BOARD_MEMBERS]>>
       "You're on the board!  A congratulations is in order."  |
    Set[*HISTORIANS]>>
       "You are busy chronicling every deft play."
    end

    for name in BOARD_MEMBERS|["Arthur"]
    assert_equal "Either you are a board member... or you are Arthur." ,
    Set["Arthur",*BOARD_MEMBERS]>>
       "Either you are a board member... or you are Arthur."   \
    === name
    end

    for name in YAHOOS|HISTORIANS
    assert_nil \
    Set["Arthur",*BOARD_MEMBERS]>>
       "Either you are a board member... or you are Arthur."   \
    === name
    end

    for name in BOARD_MEMBERS|HISTORIANS
    assert_equal "We welcome you all to the First International
        Symposium of Board Members and Historians Alike.",
    name.alter( Set[*BOARD_MEMBERS|HISTORIANS]>>
       "We welcome you all to the First International
        Symposium of Board Members and Historians Alike."  
    )
    end     

    for name in YAHOOS
    assert_nil name.alter(
    Set[*BOARD_MEMBERS|HISTORIANS]>>
       "We welcome you all to the First International
        Symposium of Board Members and Historians Alike."  
    )
    end     
  end

  def test_subst
     evenwink=+[-[ OB%:even>>-[BR(:even),';)'], OB]+0,   OB.-]
    #be nice to abbreviate this to:
    #+[-[ OB<<-[BR,';)'], OB ]+0,   OB.-]
    
     #ok, now use the pattern to test something...
    
    a=(0...4).to_a
    assert_equal  [0, ';)', 1, 2, ';)',  3],
      a.alter(evenwink)
    a=(0..10).to_a
    assert_equal [0, ';)', 1, 2, ';)',  3, 4, ';)', 5, 6, ';)', 7, 8, ';)', 9, 10, ';)'], 
      a.alter(evenwink)
  end


  def assert_eee(left,right,message='assert_eee failed')
    assert(
      left===right,
      message+" left=#{left.inspect}  right=#{right.inspect}"
    )
    if ENV['NO_TEST_UNIT']: print ".";$stdout.flush end
  end

  def assert_ene(left,right,message='assert_ene failed')
    assert(
     !(left===right),
     message+" left=#{left.inspect}  right=#{right.inspect}"
    )
    if ENV['NO_TEST_UNIT']: print ",";$stdout.flush end
  end

  def check_matcher(mtrs, hash)
    Array(mtrs).each{|mtr|
        Array(hash[:matches]).each_with_index {|data,index| 
          assert_eee mtr, data, "item ##{index} should match" 
        }
        Array(hash[:unmatches]).each_with_index {|data,index| 
          assert_ene mtr, data, "item ##{index} should not match" 
        }
    }
  end
  
  def check_hash_matcher (hmtr, hash)
    check_matcher(hmtr,hash)
    check_matcher(hmtr.ordered,hash)
  end

#end #TC_Reg metaclass?

class AnyStruct
  def self.[] *a; new(*a) end
  def initialize(hash=nil)
    hash.each_pair{|name,val| set_field(name, val) } if hash
  end

  def set_field(name,val)
    eval %{class<<self; attr_accessor :#{name} end}
    self.send name.to_s+'=',val
  end
end

end
     srand;seed=srand #most seeds work, but some don't, due to bugs in makelendata


     $verbose=true if ENV['VERBOSE']
     seed=ENV['SEED'] if ENV['SEED'] 

     print "random seed is #{seed}\n"
     srand seed.to_i

if ENV['NO_TEST_UNIT']
require "assert"
  t=TC_Reg.new
  t.methods.grep(/^test_/).each{|m| t.send m}
end
