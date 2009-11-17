#
#		counting semaphore
#			by Caleb Clausen <reg-owner _at_ inforadical _dot_ net>
#			based on code by Yukihiro Matsumoto <matz@netlab.co.jp>
#
# Copyright (C) 2006  Caleb Clausen
# Copyright (C) 2001  Yukihiro Matsumoto
# Copyright (C) 2000  Network Applied Communication Laboratory, Inc.
# Copyright (C) 2000  Information-technology Promotion Agency, Japan
# 
# This code is based on the Mutex class in ruby std lib.

unless defined? Thread
  fail "Thread not available for this ruby interpreter"
end


  class ThreadError<StandardError; end unless defined? ThreadError

if $DEBUG
  Thread.abort_on_exception = true
end

#
# CountingSemaphore implements a counting semaphore that can be used to coordinate access to
# shared data from multiple concurrent threads. With a counting semaphore, multiple requesters
# can all hold the lock at the same time. An internal count limits the number of simultaneous
# lock-holders. (The count is initialized from the contructor's parameter.) A mutex is the
# special case of a counting semaphore when the count is 1. 
#
# Example:
#
#   require 'countingsemaphore'
#   semaphore = CountingSemaphore.new(2)
#   
#   a = Thread.new {
#     semaphore.synchronize {
#       # access shared resource
#     }
#   }
#   
#   b = Thread.new {
#     semaphore.synchronize {
#       # access shared resource
#     }
#   }
#
#   c = Thread.new {
#     semaphore.synchronize {
#       # access shared resource
#     }
#   }
#
# #only 2 of the 3 get the lock at once.
class CountingSemaphore
  #
  # Creates a new Mutex
  #
  def initialize count=1
    @waiting = []
    @count = count
    @waiting.taint		# enable tainted comunication
    self.taint
  end

  #
  # Returns +true+ if this lock is currently held by some thread.
  #
  def locked?
    @count<=0
  end

  #
  # Attempts to obtain the lock and returns immediately. Returns +true+ if the
  # lock was granted.
  #
  def try_lock
    result = false
    Thread.critical = true
    if @count>0
      @count-=1
      result = true
    end
    Thread.critical = false
    result
  end

  #
  # Attempts to grab the lock and waits if it isn't available.
  #
  def lock
    while (Thread.critical = true; @count<=0)
      @waiting.push Thread.current
      Thread.stop
    end
    @count -= 1
    Thread.critical = false
    self
  end

  #
  # Releases the lock. 
  #
  def unlock
    Thread.critical = true
    @count += 1
    begin
      t = @waiting.shift
      t.wakeup if t
    rescue ThreadError
      retry
    end
    Thread.critical = false
    begin
      t.run if t
    rescue ThreadError
    end
    self
  end

  #
  # Obtains a lock, runs the block, and releases the lock when the block
  # completes.  See the example under Mutex.
  #
  def synchronize
    lock
    begin
      yield
    ensure
      unlock
    end
  end

  #
  # Try to obtain a lock, run the block, and release the lock when the block
  # completes.  Returns false if the lock could not be obtained, else whatever the block returned.
  #
  def try_synchronize
    try_lock and begin
      yield
    ensure
      unlock
    end
  end

  #
  # If the mutex is locked, unlocks the mutex, wakes one waiting thread, and
  # yields in a critical section.
  #
  def exclusive_unlock
    Thread.critical=true
    @count += 1
    begin
	  t = @waiting.shift
	  t.wakeup if t
    rescue ThreadError
	  retry
    end
    yield
    self
  ensure
    Thread.critical=false
  end
end