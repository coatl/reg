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
require "forwardable"

SpaceshipPirate=proc{
  alias spaceship__withoutpirates <=>
  def <=>(other)
    if NumberSet::Part===other 
      res=other<=>self
      res and -res    
    else
      spaceship__withoutpirates other
    end
  end
}


[Fixnum,Bignum,Float].each{|cl| cl.instance_eval &SpaceshipPirate }

class IntegerSet
  extend Forwardable

  
  def initialize(*pieces)
    pieces.map {|r| self.insert r}
  end
  class<<self
    alias [] new
  end
  
  def_delegator :@pieces, :[]
  
  def insert(num)
    mid=high-low/2
    huh
  end
  
  def ===(num)
    @pieces.empty? and return 

    low,high=0,@pieces.size-1

    while low<high 
    case num <=> @pieces[mid=high-low/2]
      when 1: low=mid+1
      when 0: return true
      when -1: high=mid-1
      when nil: return false
      else fail "didn't expect anything else from <=>"
    end
    end
    return @pieces[low]===num
  end

  class Part
    def initialize
      abstract
    end

    def ===
      abstract
    end

    def first
      abstract
    end

    def last
      abstract
    end

    def <=>(other)
      if Part===other
        result=(self<=>other.first)
        return(result == (self<=>other.last) and result)
      end
    
      if    first> other: -1
      elsif last < other: 1
      elsif self===other: 0
      end
      #else other's in our range, but not in the bitset, what else to do?
    end
    
  end

  class Range < Part
    include Enumerable
    
    def initialize(first,last=nil,exclude_end=nil)
      last or first,last,exclude_end=first.first,first.last,first.exclude_end?
      @first,@last,@exclude_end=first,last,exclude_end||nil
    end
    class <<self; alias [] new; end
    
    attr_reader :first,:last
    alias begin first
    alias end last
    
    def exclude_end?; @exclude_end end
    
    def ===(num)
      lt=@exclude_end && :< || :<=
      num>=@first and num.send lt,@last
    end
    alias member? ===
    alias include? ===
    
    def to_s
      "#{@first}..#{@exclude_end && "."}#{@last}"
    end
    alias inspect to_s
    
    def eql?(other)
      Range===other||::Range===other and
      @first.eql? other.first and
      @last.eql? other.last and
      @exclude_end==other.exclude_end?
    end
    
    def each
      item=@first
      until item==@last
        yield item
        item=item.succ!
      end
      yield item unless @exclude_end
      return self
    end
    
    def step(skipcnt)
      item=@first
      cnt=1
      until item==@last
        if (cnt-=1).zero?
          cnt=skipcnt
          yield item
        end
        item=item.succ!
      end
      yield item unless @exclude_end || cnt!=1
      return self    
    end
  end


  class Fragment < Part
    include Enumerable

  private    
    #only works for integers in the range 0..255
    def ffs(i)
      #Integer===i and (0..255)===i or raise #hell
      return -1 if i.zero?
      if (i&0x0F).nonzero?
      if (i&0x03).nonzero?
      if (i&0x01).nonzero?: 1
      else                  2
      end
      else
      if (i&0x04).nonzero?: 3
      else                  4
      end
      end
      else
      if (i&0x30).nonzero?
      if (i&0x10).nonzero?: 5
      else                  6
      end
      else
      if (i&0x40).nonzero?: 7
      else                  8
      end
      end
      end
    end
    def fls(i)
      ffs(
        i=(i&0xaa)>>1 | (i&0x55)<<1
        i=(i&0xcc)>>2 | (i&0x33)<<2
        i=(i&0xF0)>>4 | (i&0x0F)<<4
      )
    end
    
  public  
    #base is an Integer, bits is a (bit-)String
    attr_reader :base, :bits
  
    def initialize(*nums)
      nums.sort!
      nums.last-nums.first >= 800 and huh #@bits gets rediculously large
      @base=nums.first&~7
      @bits="\0"
      nums.each{|num| self<<num}
    end
    
    def insert(num)
      num-=@base
      num<0 and  huh #change base and prepend null bytes to bits...
      i=byteidx(num)
      i>@bits.size+50 and huh #lotsa dead space in @bits...
      @bits[i] |= (1<<bitidx(num))
      return self
    end
    alias << insert
    
    def delete(num)
      num-=@base
      num<0 and  return #num isn't in this set
      i=byteidx(num)
      i>=@bits.size and return #num isn't in this set
      @bits[i] &= ~(1<<bitidx(num))
      i==@bits.size-1 and @bits.sub!(/\x0+$/,'')
      if i.zero?
         @bits.sub!(/^(\x0+)/,'')
         @base+=$1.size*8
      end
      return self
    end
  
    def |(other)
      case other
      when Integer: return dup<<other    
      when ::Range: huh
      when Range: huh
      when Fragment: huh
      when Set: #??
        result=dup
        other.each{|i| result<<i }
      else huh
      end
      huh
    end
    
    def &(other)
      case other
      when Integer: return self===other && other    
      when ::Range: huh
      when Range: huh
      when Fragment: huh
      when Set: huh#??
      else huh
      end
      huh
    end
  
    def ^(other)
      case other
      when Integer:
        result=dup
        result===other ? result.delete other : result.insert other
      when ::Range: huh
      when Range: huh
      when Fragment: huh
      when Set: huh#??
      else huh
      end
      huh
    end
  
    def begin
      assert @bits[0].nonzero?
      @base+ffs(@bits[0])-1
    end
    
    def end
      assert fls(@bits[-1]).nonzero?
      @base+ (@bits.length-1)*8 + fls(@bits[-1])-1
    end
    
    alias first begin
    alias last end

    def  bitidx(num) num&7 end
    def  byteidx(num) (num&~7)>>3 end
    
    def ===(num)
      num-=@base
      num<0 and return false
      (@bits[byteidx(num)]&(1<<bitidx(num))).nonzero?
    end
    
    def each
      (0...@bits.size).each{|idx|
        bits=@bits[idx]
        until bits.zero?
          bit=ffs(bits)-1  #ffs not defined yet...
          yield @base + idx*8 + bit
          bits &= ~(1<<bit)
        end
      }
      return self
    end
  end
end
