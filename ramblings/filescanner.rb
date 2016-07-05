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

=begin rdoc
FileScanner is a module that provides StringScanner-like functionality for Files. 
The following StringScanner methods are emulated:
  #scan(pattern)
  #skip(pattern)
  #check(pattern)
  #match?(pattern) and exist?(pattern)




about anchors:
when going forward:
  \A ^ match current position
  \Z $ match end of data (String, File, whatever)
when going backward:
  \A ^ match beginning of data
  \Z $ match current position

^ and $ also match at line edges, as usual


My strategy is to rewrite the anchors in the regexp to make them conform to 
the desired definition. For instance, \Z is replaced with (?!), unless the 
last byte of the file is within the buffer to be compared against, in which 
case it is left alone. 

To counter the speed problem, there's a cache so the same regexp doesn't 
have to be rewritten more than once. 

about matchdata:
#pre_match/#post_match may not be what you expect
#offset


=end

begin
  raise LoadError.new if $DISABLE_BOC
  require 'binding_of_caller'
rescue LoadError: 
  warn "No Binding.of_caller. Regexp#=== and Regexp#match only take Strings."
end


class Regexp
  class <<self
    attr_accessor :last_file_match
  end


  DEFAULT_BUFLEN=1024


  alias eee_string ===
  alias match_string match

if defined? Binding.of_caller #not enabled yet
  def ===(other)
         #thanks to Mauricio Fernandez for this trick
       Binding.of_caller(other) do |b,other|
           unless other.respond_to? :read
             eee_string other
           else
             $~=match_file other
           end
           eval("lambda{|x| $~ = x}", b).call($~)
           nil != $~
       end
 
  end
  
  
  def match(other)
         #thanks to Mauricio Fernandez for this trick
       Binding.of_caller(other) do |b,other|
           unless other.respond_to? :read
             match_string other
           else
             $~=match_file other
           end
           eval("lambda{|x| $~ = x}", b).call($~)
           $~
       end
  end

  def self.last_match
    huh #dunno if this will work....
    Binding.of_caller{$~}
    
    #Binding.of_caller{eval"$~"}  #maybe this is needed?
  end
=begin Mauricio adds:
I forgot to add that you can probably rewrite Regexp.last_match (using
thread-local vars) if you don't really care about $~ itself; the obvious
implementation requires several other redefinitions though
({Kernel,String}#gsub(!?), String#scan, etc.).
=end
#I don't think I'll do all that...

end #binding.of_caller


  #-------------------------------------
  #this version is fast and simple, but anchors do not work right,
  #matches are NOT implicitly anchored to the current position, and
  #the file position is not advanced. post_match (or pre_match if
  #going backwards) is always nil.
  def match_file_fast(f,len=DEFAULT_BUFLEN)
    f.respond_to? :read or return lengthmatch(f,len,false)

    str=f.read(len)
    f.pos-=str.size
    Regexp.last_file_match= result=
      if match_string(str)
        result.extend Module.new do
          define_method((len >= 0)? :post_match : :pre_match) {nil} 
        end
        result
      end
  end
  
  
  
  #-------------------------------------
  #like match_file, but goes backwards
  def match_file_back(f,len=DEFAULT_BUFLEN,anchored=false)
    
    newrex,addedgroups=nearbegin(f,len)? [self,[]]:group_anchors(true,anchored)
    #do the match against what input we have
    
    f.pos-= len
    matchdata=(newrex).match_file_fast len
    f.pos+= len
    #fail if any $ or \Z (or ^ or \A) matched at end (or begin) of buffer, 
    #but buffer isn't end (or begin) of file
    return Regexp.last_file_match=nil if !matchdata or #not actually a match
      addedgroups.find{|i| matchdata.end(i)==0 } && !nearbegin(f,len) 

    result,pos=f.dup,f.pos     #capture position in case it changes before the block runs...
    fixup_match_result(matchdata,addedgroups,:pre) do
          result.pos=pos -len + self.begin(0)
          result
        end
        #note: pre_match is a file. Getting to the unmatched part means 
        #going back, not forward, on pre_match.
    
    Regexp.last_file_match= result
  end
  
  #-------------------------------------
  #like match_file_fast, but anchors work correctly and pre/post_match is
  #set to something, if not exactly what you expected. (a File, not String.)
  def match_file(f,len=nil,anchored=false)
    return( len ? lengthmatch(f,len,anchored) \
               : match(input)) unless input.respond_to? :read
    len||=DEFAULT_BUFLEN
        
    newrex,addedgroups=nearend(f,len)? [self,[]]:group_anchors(false,false) 

    #do the match against what input we have
    #need caching here
    matchdata=(newrex).match_file_fast f

    #fail if any $ or \Z (or ^ or \A) matched at end (or begin) of buffer, 
    #but buffer isn't end (or begin) of file
    return Regexp.last_file_match=nil if !matchdata or #not actually a match
      addedgroups.find{|i| matchdata.end(i)==len } && !nearend(f,len) 

    result,pos=f.dup,f.pos     #capture position in case it changes before the block runs...
    fixup_match_result(matchdata,addedgroups,:post) do
          result.pos=pos+self.end(0)
          result
        end
        #note: post_match is a File

    anchored and matchdata.begin(0).nonzero? and return
    Regexp.last_file_match= matchdata
  end
  
  #-------------------------------------
  def lengthmatch(str,len=nil,anchored=false)
     #like match_file above, I guess
     
    unless len 
      result= match(str) 
      anchored and result.begin.nonzero? and return
      return result
    end
     
     
    len>=0 or raise ArgumentError.new
    nearedge,lenatlimit=:nearend,len
    nearend= str.size<=len
    
    newrex,addedgroups=nearend ? [self,[]] : group_anchors(false,false) 
                            

    buf=str[0...len]  

    #do the match against what input we have
    matchdata=newrex.match buf

    #fail if any $ or \Z (or ^ or \A) matched at end (or begin) of buffer, 
    #but buffer isn't end (or begin) of file
    return Regexp.last_file_match=nil if !matchdata or #not actually a match
      addedgroups.find{|i| matchdata.end(i)==lenatlimit } && !nearend

    postdata=str[matchdata.end(0)..-1]
    fixup_match_result(matchdata,addedgroups,:post) {postdata}
    
    anchored and matchdata.begin(0).nonzero? and return Regexp.last_file_match=nil

    return Regexp.last_file_match=matchdata
  end
  
  
      #attempt a match at somewhere other than first character of a string
    #ofs specifies the offset to begin matching at. 
    #if muststart is true, self must match at exactly that offset.
    #if false, self must match at the offset or anywhere later.
    #note if self has a ^ anywhere in it, it won't work.
    #really wanting :wrap here
    def match_in(str,ofs=0,anchored=nil)
      ofs.nonzero? or anchored or return match(str)
      
      str2=str[ofs..-1]
      result=match str2
      unless anchored and result.begin(0).nonzero?
        return result.extend(OffsetMatchData).prestr_set(str[0...ofs])
      end
    end
    
    module OffsetMatchData
      def prestr_set str
        @str=str
        @strlen=str.length
        return self
      end
      
      def string
        @str+super
      end
      
      def pre_match
        @str+super
      end
      
      def begin group
        @strlen+super
      end
      
      def end group
        @strlen+super
      end
      
      def offset group
        super.map{|n| @strlen+n }
      end
      
    end

private  

  #-------------------------------------
  def nearbegin(f,len)
    f.pos-len<=0
  end
  
  #-------------------------------------
  def nearend(f,len)
    f.pos+len>f.size-1
  end

  #-------------------------------------
  #replace \Z with (?!) 
  #replace $ with (?=\n) 
  #replace \A with (?!) 
  #replace ^ with (^) (and adjust addedgroups) 
  def group_anchors(backwards,anchored)
    @fs_cache||={}
    result=@fs_cache[backwards,anchored] and return result
    if backwards 
      caret,dollar,buffanchor='^',nil,'A'
    else 
      caret,dollar,buffanchor=nil,'$','Z' 
    end
    newrex=(anchored ?  Regexp.anchor(self,backwards) : to_s)

    incclass=false
    groupnum=0
    addedgroups=[]
    (frags=newrex.split( /((?:[^\\(\[\]$^]+|\\(?:[CM]-)*[^CMZA])*)/ )).each_index{|i|
      frag=frags[i]
      case frag
        when "\\": 
          if !incclass and frags[i+1][0,1]==buffanchor
            frags[i+1].slice! 0
            frag='(?!)'
            rewritten=true
          end
        when caret 
          unless incclass
            addedgroups<<(groupnum+=1)
            frag="(^)"
            rewritten=true
          end
        when dollar 
          unless incclass
            frag="(?=\n)"
            rewritten=true
          end
        when "(": incclass or frags[i+1][0]==?? or groupnum+=1
        when "[": incclass=true #ignore stuff til ]
        when "]": incclass=false #stop ignoring stuff
      end
      newrex<<frag
    }
    
    newrex=rewritten ? Regexp.new(newrex) : self
    
    @fs_cache[backwards,anchored]=[newrex,addedgroups]
  end
   
=begin   
  #or
  
  #find $ and \Z (or ^ and \A if backwards) in regex and surround with () 
  #returns the modified regex (as a string), and a list of group indexes that were inserted
  def group_anchors(backwards)
    lineanchor,buffanchor=*if backwards: ['^','A'] else ['$','Z'] end
    newrex=''
    incclass=false
    groupnum=0
    addedgroups=[]
    (frags=to_s.split( /((?:[^\\(\[\]$^]+|\\(?:[CM]-)*[^CMZA])*)/ )).each_index{|i|
      frag=frags[i]
      case frag
        when "\\": 
          if !incclass and frags[i+1][0,1]==buffanchor
            frags[i+1].slice! 0
            frag="(\\#{buffanchor})"  #surround with ()
            addedgroups<<(groupnum+=1)
          end
        when lineanchor: 
          unless incclass
            frag="(#{frag})"  #surround with ()
            addedgroups<<(groupnum+=1)
          end
        when "(": incclass or frags[i+1][0]==?? or groupnum+=1
        when "[": incclass=true #ignore stuff til ]
        when "]": incclass=false #stop ignoring stuff
      end
      newrex<<frag
    }
    
    
    return newrex,addedgroups
  end
  
=end

  #-------------------------------------
  def Regexp.anchor(str,backwards=false)
    backwards ? "(?:#{str})\\Z" : "\\A(?:#{str})"
  end
  
  #-------------------------------------
  def fixup_match_result(matchdata,addedgroups,namelet,&body)
    
    #remove extra capture results from () we inserted from MatchData
    #..first extract groups, begin and end idxs from old
    groups=matchdata.to_a
    begins=[]
    ends=[]
    (0...matchdata.length).each{|i| 
      begins<<matchdata.begin(i)
      ends<<matchdata.end(i)
    }
    
    #..remove data at group indexes we added above
    addedgroups.reverse_each{|groupidx| 
      [groups,begins,ends].each{|arr| arr.delete_at groupidx }
    }
    
    #..now change matchdata to use fixed-up arrays
    matchdata.extend CorrectedMatchData
    matchdata.begins=begins
    matchdata.ends=ends
    matchdata.groups=groups
    matchdata.redef_pmatcher namelet,&body
    matchdata.pos=huh
  end    
  
  

  #-------------------------------------
  module CorrectedMatchData
    attr_accessor :pos
    attr_writer :begins,:ends,:groups
    def [](*args); @groups[*args] end
  
    def begin n;  @begins[n] end
    def end n;    @ends[n] end
    def offset n; [@begins[n],@ends[n]] end
  
    def to_a;     @groups end
    def size;     @groups.size end
    alias length size
    
    def pre_match; nil end
    alias post_match pre_match
    
    def redef_pmatcher(namelet,&pmatcher)
      @pmatcher=pmatcher
      eval "
        def self.#{namelet}_match
          @pmatcher[]
        end
      "
    end
  end
  
end


MatchWriter=proc do #proc as module
    #-------------------------------------
    def write_match_func(name,anchored,advance,returnlen)
      anchored||=false
      name=name.to_s
      name1by1=case name
        when /^(.*)!$/: $1+'X'
        when /^(.*)\?$/:$1+'Q'
        when /^(.*)=$/: $1+'E'
        else name
      end+"_1by1"
      to_eval= %{
        
        alias #{name1by1} #{name}
        def #{name}(rex,len=buflen,*rest)
          case rex 
          when Regexp
            md=rex.match_file(self,len,#{anchored}) or return
            dat=md[0]
            consumed=md.end(0)
          when String
            #{if anchored: "
              test= rex==(dat=read(rex.size) )
              self.pos-=consumed=dat.size
              test or return
            " else "
              dat=read(len)
              self.pos-=dat.size
              dat.scan rex
              consumed=
            " end }
          when Integer
            #{"warn '_until methods dont make much sense with int args'" unless anchored}
            rex>= 0 or return
            dat=read(rex) 
            self.pos-=consumed=dat.size
            consumed==rex or return
           
          else return super
          end
          
          #{advance and "self.pos+= consumed"}
          return #{returnlen ? :consumed : :dat}
        end
      }
          puts to_eval
          eval to_eval
    end

    #-------------------------------------
    def write_matchback_func(name,anchored,advance,returnlen)
      anchored||=false
      eval %{
        def #{name}(rex,len=buflen,*rest)
          case rex 
          when Regexp
            md=rex.match_file_back(self,len,#{anchored}) or return
            dat=md[0]
            consumed=len-md.begin(0)
          when String
            size=rex.size
            self.pos>=size or return
            self.pos-=size
            test= rex==(dat=read(size) )
            consumed=dat.size
            test or return  
          when Integer
            self.pos>=rex or return
            #{if returnlen  
                "consumed=rex"
              else
                "self.pos-=consumed=rex
                 dat=read(rex)"
              end
             }
           
          else return super
          end

          #{advance and "self.pos-= consumed"}
          return #{returnlen ? :consumed: :dat}
        end
      }
    end
    
    #-------------------------------------
    def write_match_funcs(name,*flags)
      write_match_func name,true,*flags
      write_match_func "#{name}_until",false,*flags
      write_matchback_func name+="back",true,*flags
      write_matchback_func "#{name}_until",false,*flags
    end
end

module FileScanner
  class <<self
    instance_eval &ModuleWriter
  end
  
public  
  def buflen; @buflen||=Regexp::DEFAULT_BUFLEN end
  attr_writer :buflen
  
  
  #-------------------------------------
  #-------------------------------------
  def exist?(curs,len=buflen)
    md=match_file(curs,len,false) and md.begin(0)
  end
  def existback?(curs,len=buflen)
    md=match_file_back(curs,len,false) and md.end(0)
  end
  write_match_func :match?, true,  nil, true
  write_match_func :matchback?, true,  nil, true, true
  
  write_match_funcs :skip, true,true
  write_match_funcs :scan, true,false
  write_match_funcs :check, nil,false
end


class File
  def size; stat.size; end
  
  def [](*args)
    SubFile.new self, *args
  end
end



class SubFile
  attr_reader :offset,:len,:file
  
  def initialize(file,offset, len=nil)
    if Range===offset  
      len=offset.end - offset.begin
      offset.exclude_end? and len-=1
      offset=offset.first
    end
    @file,@offset,@len=file.dup,offset,len
    rewind
  end
  
  #fiddle with these methods from IO:
  #all from Enumerable

  #it's not this simple... this all has to be a proc that gets instance_eval'd by #included...
  #and I can't call super.... uragggg!


  def rewind;     @file.pos=@offset end
  
  def size; @len end
  
  def tell; @file.tell-@offset end
  alias pos tell
  
  def seek(amt,whence=IO::SEEK_SET)
    case whence
      when IO::SEEK_CUR: 
      when IO::SEEK_SET: amt+=@offset
      when IO::SEEK_END: amt+=@offset+@len;whence=IO::SEEK_SET
    end
    result=@file.seek(amt,whence)
    fixup_pos
    result
  end
  
  def sysseek(amt,whence=IO::SEEK_SET)
    case whence
      when IO::SEEK_CUR: 
      when IO::SEEK_SET: amt+=@offset
      when IO::SEEK_END: amt+=@offset+@len;whence=IO::SEEK_SET
    end
    result=@file.sysseek(amt,whence)
    fixup_pos
    result
  end
  
  def pos=n; seek n end
  
  def eof?; pos>=@len; end
  alias eof eof?
  
  def getc
    eof??nil:@file.getc 
  end
  
  def readchar
    eof?? raise(EOFError.new) : @file.readchar 
  end
  
  def read(chars=size,result='')
    left=size-(pos+chars)
    left<0 and chars+=left
    @file.read(chars,result)
  end
  
  def sysread(chars=size)
    left=size-(pos+chars)
    left<0 and chars+=left
    @file.sysread(chars)
  end
  
  def each_byte
    until eof?
      yield readchar
    end
    nil
  end
  
  def gets(sepstr=$/)
    eof? and return nil
    result=@file.gets
    f=fixup_pos
    f<0 and    result=result[0...f]
    return result    
  end
  
  def readline(sepstr=$/)
    eof? and raise EOFError.new
    
    gets sepstr
  end
  
  def each_line
    while str=gets
      yield str
    end
  end
  alias each each_line
    
  def readlines(sepstr=$/)
    result=[]
    while str=gets(sepstr)
      result<<str
    end 
    return result
  end
  
  [:print, :printf, :putc, :puts,:<<,  :write, :syswrite,:binmode,:chmod,:chown,:flock,:truncate].each {|unallowed|
    define_method unallowed do
      raise IOError.new
    end
  }
     #not sure about these:
#      to_i, to_io,fileno,     ungetc
  
  #leave these alone:
 #close, close_read, close_write, closed?,  fcntl, , flush, fsync,
 #initialize_copy, inspect, ioctl, isatty, 
 #    pid,  reopen,  stat, sync, sync=,
 #     tty?, lineno, lineno=,

      
      
  private
  def fixup_pos(p=pos)
    diff=@offset-p
    if diff >0 or (diff+=@len) < 0; 
      seek diff
    else return 0
    end
    return diff
  end     
      
end

