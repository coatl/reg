#
#		ring buffer
#			by Caleb Clausen <reg-owner _at_ inforadical _dot_ net>
#			based on code by Yukihiro Matsumoto <matz@netlab.co.jp>
#
# Copyright (C) 2006, 2016  Caleb Clausen
# Copyright (C) 2001  Yukihiro Matsumoto
# Copyright (C) 2000  Network Applied Communication Laboratory, Inc.
# Copyright (C) 2000  Information-technology Promotion Agency, Japan
#

unless defined? Thread
  fail "Thread not available for this ruby interpreter"
end

  class ThreadError<StandardError; end unless defined? ThreadError

if $DEBUG
  Thread.abort_on_exception = true
end


#
# This class provides a way to synchronize communication between threads.
#
# Example:
#
#   require 'ringbuffer'
#   
#   queue = RingBuffer.new
#   
#   producer = Thread.new do
#     5.times do |i|
#       sleep rand(i) # simulate expense
#       queue << i
#       puts "#{i} produced"
#     end
#   end
#   
#   consumer = Thread.new do
#     5.times do |i|
#       value = queue.pop
#       sleep rand(i/2) # simulate expense
#       puts "consumed #{value}"
#     end
#   end
#   
#   consumer.join
#
class RingBuffer
  #
  # Creates a new ring buffer.
  #
  def initialize size=64
    @buffer = Array.new(size)
    @readidx=@writeidx=0
    @readwaiter = @writewaiter = nil
    @buffer.taint		# enable tainted comunication
    self.taint
  end

  def full?
    @writeidx==@readidx-1
  end
  
  def empty?
    @writeidx==@readidx
  end

  #
  # Pushes +obj+ to the queue.
  #
  def push(obj)
    Thread.critical=true
    if full?
      @writewaiter=Thread.current
      Thread.stop
    end
    Thread.critical=false
    @buffer[@writeidx]=obj
    @writeidx+=1
    @writeidx>=@buffer.size and @writeidx=0
    begin
      Thread.critical=true
      t = @readwaiter
      @readwaiter=nil
      Thread.critical=false
      t.wakeup if t
    rescue ThreadError
      retry
#    ensure
#      Thread.critical = false
    end
    begin
      t.run if t
    rescue ThreadError
    end
  end

  #
  # Alias of push
  #
  alias << push

  #
  # Alias of push
  #
  alias enq push

  #
  # Retrieves data from the queue.  If the queue is empty, the calling thread is
  # suspended until data is pushed onto the queue.  If +non_block+ is true, the
  # thread isn't suspended, and an exception is raised.
  #
  def pop(non_block=false)
    while (empty?)
      raise ThreadError, "queue empty" if non_block
      Thread.critical=true
      @readwaiter= Thread.current
      Thread.stop
      Thread.critical=false
    end
    result=@buffer[@readidx]
    @readidx+=1
    @readidx>=@buffer.size and @readidx=0
    
    begin
      Thread.critical=true
      t = @writewaiter
      @writewaiter=nil
      Thread.critical=false
      t.wakeup if t
    rescue ThreadError
      retry
#    ensure
#      Thread.critical = false
    end
    begin
      t.run if t
    rescue ThreadError
    end
    
    result
  end

  #
  # Alias of pop
  #
  alias shift pop

  #
  # Alias of pop
  #
  alias deq pop
  
  def peek(len=nil)
    wi=@writeidx
    sz=wi-@readindex
    sz<0 and sz+=@buffer.size
    len.nil? || len>sz and len=sz
    
    if wi>= @readindex
      @buffer[@readidx,len]
    else
      @buffer[@readidx..-1]+@buffer[0...@writeidx]    
    end
  end
  
  def read(len=size)
    result=[]
    while len > 0
      result<<peek(len)
      len-=result.size
      @readidx=(@readidx+result.size)%@buffer.size
    end 
    begin
      Thread.critical=true
      t = @writewaiter
      @writewaiter=nil
      Thread.critical=false
      t.wakeup if t
    rescue ThreadError
      retry
#    ensure
#      Thread.critical = false
    end
    begin
      t.run if t
    rescue ThreadError
    end
    result
  end
  
  
  #try to write data into the ring buffer without moving the write index
  #the whole data might not get written, if there's not enough room.
  #the actual number of items poked is returned.
  def poke(data)
    huh
  end
  
  def write(data)
    idx=0
    loop do
    while idx<data.size
      ri=@readidx
      sz=@writeidx-ri
      if sz<0 
      sz+=@buffer.size
      else
      
      end
      
      
    end
    
    
    huh 
  end
  


  #
  # Removes all objects from the queue.
  #
  def clear
    @readidx=@writeidx
  end

  #
  # Returns the length of the queue.
  #
  def length
    result=@writeidx-@readidx
    result<0 and result+=@buffer.size
    result
  end

  #
  # Alias of length.
  #
  alias size length

  #
  # Returns the number of threads waiting on the queue.
  #
  def num_waiting
    @readwaiter||@writewaiter ? 1 : 0
  end
end
