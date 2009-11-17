module Kernel
  def warning(msg)
    (
     (defined? $Debug) && $Debug or 
     (defined? $DEBUG) && $DEBUG or 
     (defined? $VERBOSE) && $VERBOSE
    ) or return

    #emit each warning only once
    @@seenit__||={}
    clr=caller[0]
    callerid,mname=clr.match(/^(.*:[0-9]+)(?::in (.*))?$/)[1..2]
    mname=mname[1..-2] if /^`.*'$/===mname
    @@seenit__[callerid] and return
    @@seenit__[callerid]=1
  
    warn [callerid,": warning: (",mname,") ",msg].join
  end  
end
