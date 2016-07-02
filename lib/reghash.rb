
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





module Reg


  class Hash
    include Reg,Composite
    include CausesBacktracking #of course, it's not implmented correctly, right now
    attr :others
    
    def initialize(hashdat=nil)
      @matchers={}
      @literals={}
      @others=nil
      hashdat or return 
      hashdat.key?(OB) and @others=hashdat.delete(OB) 
      hashdat.each {|key,val| 
        key=Deferred.defang! key
        val=Deferred.defang! val
        if Reg.interesting_matcher? key
          Fixed===key and key=key.unwrap
          @matchers[key]=val
        else
          Equals===key and key=key.unwrap
          @literals[key]=val
        end
      }    
      super
    end

    def initialize_copy(other)
      @matchers,@literals=*other.instance_eval{[@matchers,@literals]}.map{|x| x.clone }
      @others=other.instance_eval{@others}
      @others=@others.clone if @others
    end

    def self.[](*args); new(*args); end

    def matches_class; ::Hash end

    def loose
      result=clone
      result.instance_variable_set(:@others,OB)
      result
    end
    alias -@ loose
    
    def ordered
      pairs=[]
      @literals.each{|k,v| pairs<< Pair[k,v] }
      @matchers.each{|k,v| pairs<< Pair[k,v] }
      pairs<<Pair[OB,@others] if @others
      return +pairs
    end

    def subregs;
      @literals.keys + @literals.values +
      @matchers.keys + @matchers.values + 
      (@others==nil ? [OB,@others] : [])
    end
    
    def inspect
      name="$RegInspectRecursing#{object_id}"
      Thread.current[name] and return '+{...}'
      Thread.current[name]=true
      
      result=[]
      result<<@literals.inspect[1..-2] unless @literals.empty?
      result<<@matchers.inspect[1..-2] unless @matchers.empty?
      result<<"_=>#{@others.inspect}"  if defined? @others and @others!=nil
      Thread.current[name]=nil
      return "+{#{result.join(", ")}}"
    end
      
    def ===(other)
      matchedliterals={}
      matchedmatchers={}
      other.each_pair{|key,val|
        #literals get a chance first
        @literals.key? key and 
          if (@literals[key]===val rescue false)
            matchedliterals[key.__id__]=true
            next
          else
            return
          end 
        
        #now try more general matchers
        saw_matcher=nil
        @matchers.each_pair{|mkey,mval|
          if (((mkey===key) rescue false))
            return unless (mval===val rescue false)
            saw_matcher=matchedmatchers[mkey.__id__]=true
            break 
          end
        }
        
        
        #last of all, try the catchall
        saw_matcher or (@others===val rescue false) or return
      }
        
        #make sure each pattern matched some key/value pair (even if it's the hash's #default value)
        #...make sure each literal matched some key/value (or #default)
      @literals.each_pair{|k,v| matchedliterals[k.__id__] or v==(other.default k) or return }

        #...make sure each matcher matched some key/value (or #default)
      @matchers.each_pair{|k,v| matchedmatchers[k.__id__] or (v===other.default rescue false) or return }      

        #...empty hash values match if catchall matches hash's #default value
        #...and matcher was empty (except for catchall)
      other.empty? and @literals.empty? and @matchers.empty? and return (@others===other.default rescue false)
      
      
      return true
    end

    #too similar to #===
    def mmatch_full(progress)
      other= progress.cursor.readahead1
      progress.newcontext self,other
      matchedliterals={}
      matchedmatchers={}
      other.each_pair{|key,val|
        progress.context_index=key
        #literals get a chance first
        progress.with_context GraphPoint::HashKey, val
        @literals.key? key and 
          if @literals[key].mmatchhuh val
            matchedliterals[key.__id__]=true
            next
          else
            return
          end 
        
        #now try more general matchers
        progress.with_context GraphPoint::HashKey, key
        saw_matcher=nil
        @matchers.each_pair{|mkey,mval|
          if mkey.mmatch progress
            progress.with_context GraphPoint::HashValue, val
            return unless (mval.mmatchhuh val)
            saw_matcher=matchedmatchers[mkey.__id__]=true
            break 
          end
        }
        
        
        #last of all, try the catchall
        progress.with_context GraphPoint::HashValue, val
        saw_matcher or @others.mmatch progress or return
      }
      progress.context_index=nil
      progress.with_context GraphPoint::HashDefaultValue,(other.default)
      
      #make sure each pattern matched some key/value pair (even if it's the hash's #default value)...
      #...make sure each literal matched some key/value (or #default)
      @literals.each_pair{|k,v| matchedliterals[k.__id__] or v==(other.default k) or return }
      
      #...make sure each matcher matched some key/value (or #default)
      @matchers.each_pair{|k,v| matchedmatchers[k.__id__] or v.mmatch progress or return }      
      
      #...empty hash values match if catchall matches hash's #default value
      #...(and matcher was empty (except for catchall))
      other.empty? and (@literals.empty? and @matchers.empty?) and return @others.mmatch( progress )
      return [true, 1]
    ensure 
      progress.endcontext
    end
    
    #tla of +{}
#    assign_TLAs :Rah=>:Hash
   
  end
  
  #--------------------------
  class RestrictHash
    include Reg,Composite
    def initialize a_hash
      @filters=a_hash
      super
    end
    
    def inspect
      name="$RegInspectRecursing#{object_id}"
      Thread.current[name] and return huh
      Thread.current[name]=true
      huh
      Thread.current[name]=nil
    end
    
    def subregs
      huh
    end
    
    def to_h
      @filters
    end
    
    def === other
      result={}
      other.each_pair{|okey,oval|
        @filters.each_pair{|fkey,fval|
           if (fkey===okey rescue false) and (fval===oval rescue false)
             result[okey]=oval
             break
           end
        }
      }
      result unless result.empty?
    end

    #too similar to #===
    def mmatch_full(progress)
      huh  "need to use  ::Sequence::SingleItem"
      other= progress.cursor.readahead1
      progress.newcontext self,other
      result={}
      other.each_pair{|okey,oval|
        @filters.each_pair{|fkey,fval|
           progress.context_index=okey
           
           progress.with_context GraphPoint::HashKey, okey
           fkey.mmatch progress or next
           
           progress.with_context GraphPoint::HashValue, oval
           fval.mmatch progress or next  
           
           result[okey]=oval
           break
        }
      }
      progress.endcontext
      return [true,1] unless result.empty?
    end
  end
  
  #--------------------------
  class OrderedHash
    include Reg,Composite
    include CausesBacktracking #of course, it's not implmented correctly, right now
    def initialize(*args)
      @keys=[]
      @vals=[]
      @others=nil
      args.each{|a|
        if Pair===a
          l,r=a.left,a.right
          Fixed===l and l=l.unwrap
          if l==OB
            @others=r
          else
            @keys<<Deferred.defang!(l)
            @vals<<Deferred.defang!(r)
          end
        else
          @keys<<Deferred.defang!(a)
          @vals<<OB
        end
      }
      super
    end
  
    def ===(other)
      matched=0
      saw1=nil
      other.each_pair do |ko,vo|
        saw1=nil
        @vals.each_index do|i| 
            kr,vr=@keys[i],@vals[i]
            if (kr===ko rescue false)
              (vr===vo rescue false) or return
              saw1=matched |= 1<<i
              break
            end 
        end
        saw1 or ((@others===vo rescue false) or return)
      end
      @vals.each_index {|i|
        if (matched&(1<<i)).zero?
          dflt=other.default((@keys[i] unless Reg::interesting_matcher? @keys[i]))
          (@vals[i]===dflt rescue false) or return
        end
      }
      other.empty? and @vals.empty? and  return (@others===other.default rescue false)
      return other     
    end
    
    #too similar to #===
    def mmatch_full(progress)
      huh
      other= progress.cursor.readahead1
      progress.newcontext self,other
      
      matched=0
      saw1=nil
      other.each_pair do |ko,vo|
        progress.context_index=ko
        saw1=nil
        @vals.each_index do|i| 
            kr,vr=@keys[i],@vals[i]
            progress.with_context GraphPoint::HashKey, vo
            if kr.mmatch progress 
              progress.with_context GraphPoint::HashValue, ko
              vr.mmatch progress or return
              saw1=matched |= 1<<i
              break
            end 
        end
        progress.with_context GraphPoint::HashValue, vo
        saw1 or (@others.mmatch progress or return)
      end
      @vals.each_index {|i|
        if (matched&(1<<i)).zero?
          default=other.default((@keys[i] unless Reg::interesting_matcher? @keys[i]))
          progress.with_context GraphPoint::HashDefaultValue, default
          @vals[i].mmatch progress or return
        end
      }
      progress.with_context GraphPoint::HashDefaultValue, other.default
      other.empty? and @vals.empty? and  return( @others.mmatch progress )
      return [true,1]   
    ensure
      progress.endcontext
    end

    def self.[](*args); new(*args); end

    def matches_class; ::Hash end
    
    def inspect
      name="$RegInspectRecursing#{object_id}"
      Thread.current[name] and return '+[...**...]'
      Thread.current[name]=true
      result="+[#{
        str=''
        each_pair{|k,v| 
          str<< k.inspect+ ((Reg===k)? "" : ".reg") +
                "**"+v.inspect+", " unless OB==k && nil==v
        }
        str
      }]"
      Thread.current[name]=nil
      result
    end
    def subregs
      result=@keys+@vals
      result.push @others if @others
      result
    end
    
    def each_pair
      @keys.each_index{|i|
        yield @keys[i],@vals[i]
      }
      yield OB,@others
    end
#    include Enumerable
    
    
    def to_ruby
      result= "def self.===(a_hash)\n"
      result<<"  a_hash.each_pair{|k,v|\n"
      result<<"    (case k\n"
      @keys.each_index{|i|
        result<<"    when #{@keys[i]}: #{vals[i]}\n"
      }
      result<<"    else #{@other}\n" +
              "    end===v rescue false) or break\n" +
              "  }\n" +
              "end\n"
      
      return result
    end
  end

  #--------------------------
  class Object #< Hash
  #decending from Hash isn't particularly useful here
  #it looks like everything is overridden, anyway
    include Reg,Composite
    include CausesBacktracking #of course, it's not implemented correctly, right now

    def initialize(*args)
      hash= (::Hash===args.last ? args.pop : {})
      
      @vars={}; @meths={}; @meth_matchers={}; @var_matchers={}
      hash.each_pair{|item,val|
        if ::String===item or ::Symbol===item
          item=item.to_s
          (/^@@?/===item ? @vars : @meths)[item.to_sym]=Deferred.defang! val
        elsif Regexp===item && item.source[/^\^?[@A-Z]/]
          @var_matchers[item]=Deferred.defang! val
        elsif Wrapper===item
          @meth_matchers[item.unwrap]=Deferred.defang! val
        else 
          @meth_matchers[Deferred.defang!( item )]=Deferred.defang!( val )
        end
      }
      @meths[:class]=args.shift if (Class===args.first)
            
      super
    end
    def self.[](*args) new(*args); end


    def inspect
      name="$RegInspectRecursing#{object_id}"
      Thread.current[name] and return '+[...**...]'
      Thread.current[name]=true
      result=  "-{#{
          [@vars,@meths,@var_matchers,@meth_matchers].map{|h| 
            h.inspect[1..-2]+", "
          }}}"
      Thread.current[name]=nil
      result
    end
    
    def subregs
      @vars.keys+@vars.values+
      @meths.keys+@meths.values+
      @meth_matchers.keys+@meth_matchers.values+
      @var_matchers.keys+@var_matchers.values
    end
    
    def to_h
      [@vars,@meths,@meth_matchers,@var_matchers].inject{|sum,h|
        sum.merge h
      }
    end

    def ===(other)
      seenmeths=[];seenvars=[]; #maybe not needed?
      seenvarmats=[];seenmats=[]
      @meths.each_pair{|name,val|
        (val===other.send(name) rescue false) or return
        seenmeths<<name
      }
      @vars.each_pair{|name,val|
        (val===other.instance_eval(name.to_s) rescue false) or return
        seenvars<<name
      }
      @meth_matchers.empty? or other.public_methods.each {|meth|
        #I should consider preventing methods that are in Object.instance_methods from being called here
        #or perhaps only known dangerous methods from Object and Kernel such as #freeze and #send
        next if seenmeths.include? meth 
        @meth_matchers.each_pair{|name, val| 
          if (name===meth rescue false)
              (val===other.send(meth) rescue false) or return 
              seenmats<< name.__id__
          end
        }
      }
      
      @var_matchers.empty? or other.instance_variables.each {|var|
        next if seenvars.include? var
        @var_matchers.each_pair{|name,val|
          if (name===var and val===other.instance_eval(name.to_s) rescue false)
              seenvarmats<<name.__id__
          end
        }
      }
      #todo:should support class, global, and constant variables here too?!
      
      @meths.keys.-(seenmeths).empty? or return
      @vars.keys.-(seenvars).empty? or return
      @meth_matchers.keys.map{|k| k.__id__}.-(seenmats).empty? or return
      @var_matchers.keys.map{|k| k.__id__}.-(seenvarmats).empty? or return      

      return other || true
      
    rescue
      return false
    end


    #too similar to #===
    def mmatch_full(progress)
      huh    
      other= progress.cursor.readahead1
      progress.newcontext self,other
      
      seenmeths=[];seenvars=[]; #maybe not needed?
      seenmats=[];seenvarmats=[]
      @meths.each_pair{|name,val|
        progress.context_index=name
        progress.with_context GraphPoint::ObjectMethValue, other.send(name)
        val.mmatch progress or return
        seenmeths<<name
      }
      @vars.each_pair{|name,val|
        progress.context_index=name
        progress.with_context GraphPoint::ObjectIvarValue, other.instance_eval(name.to_s)
        val.mmatch progress or return
        seenvars<<name
      }
      @meth_matchers.empty? or other.public_methods.each {|meth|
        next if seenmeths.include? meth 
        @meth_matchers.each_pair{|name, val| 
          progress.context_index=meth
          progress.with_context GraphPoint::ObjectName, meth
          if name.mmatch progress
            progress.with_context GraphPoint::ObjectMethValue, other.send(meth)
            val.mmatch progress and            seenmats<< name.__id__
          end
        }
      }
      @var_matchers.empty? or other.instance_variables.each {|var|
        next if seenvars.include? var
        @var_matchers.each_pair{|name,val|
          progress.context_index=var
          progress.with_context GraphPoint::ObjectName, var
          if name.mmatch progress
            progress.with_context GraphPoint::ObjectIvarValue, other.instance_eval(name.to_s)
            val.mmatch other.instance_eval(name.to_s) and
              seenvarmats<<name.__id__
          end
        }
      }
      #todo:should support class, global, and constant variables here too!
      @meths.keys.-(seenmeths).empty? or return
      @vars.keys.-(seenvars).empty? or return
      @meth_matchers.keys.map{|k| k.__id__}.-(seenmats).empty? or return
      @var_matchers.keys.map{|k| k.__id__}.-(seenvarmats).empty? or return
      

      return [true,1]
      
    rescue Exception
      return false
    ensure 
      progress.endcontext
    end
    
    #tla of -{}
#    assign_TLAs :Rob=>:Object


  end
  
  
  #OrderedObject not even attempted yet
  
  module Reg
  
    #pairing operator
    def **(other)
      Pair[self,other]
    end
    alias to **
    
    
  end
 
  class ::Array
    #pairing operator
    def **(other)
      Pair[self,other]
    end
  end
  class ::String
    #pairing operator
    def **(other)
      Pair[self,other]
    end
  end
  class ::Symbol
    #pairing operator
    def **(other)
      Pair[self,other]
    end
  end


  class Pair
    include Reg
    class<<self; alias [] new; end
    
    attr_reader :left,:right
    
    def initialize(l,r)
      @left,@right=Deferred.defang!(l),Deferred.defang!(r)
      #super
    end
    
    def to_a; [@left,@right] end
    alias to_ary to_a    #mebbe to_ary too?

if false    #not sure if i know what i want here...
    def hash_cmp(hash,k,v)
      @left
    end
    
    def obj_cmp
    end
end  
    #tla of **
    #assign_TLAs :Rap=>:Pair


    
  end



end



