require 'forwardable'
require 'set'
require 'assert'

module Rog
  #--------------------------------
  #represents a path through the object graph
  class GraphTrace
    extend Forwardable
    def initialize(points=[])
      @points=points
    end
    
    attr_reader :points
    def_delegators :@points, :<<
  end


  #--------------------------------
  module GraphWalk
    class<<self
      #--------------------------------
      def graphcopy(obj)
        old2new={}
        root=nil
        graphwalk(obj){|cntr,o,i,ty|
          newo= block_given? && (yield cntr,o,i,ty,useit=[false]) 
          useit.first or newo ||=
            old2new[o.__id__] ||= root ||= o.dup
          ty.new(old2new[cntr.__id__],i,1){newo}.replace
        }
        return root
      end
      
      #--------------------------------
      def graphwalk(obj)
        yield nil,obj,nil,GraphEdge::TopLevel
        todolist=[obj]
        donelist=Set[]
        todolist.each{|o|
          traverse(o){|cntr,o2,i,ty|
            unless donelist.include? [cntr.__id__,ty,i]
              todolist<<o2 
              donelist<<[cntr.__id__,ty,i]
              yield cntr,o2,i,ty
            end
          }
        }
      end
    
      #--------------------------------
      def traverse(obj)
      #some other container types should be explicitly
      #supported here: Set, Struct, OpenStruct, SuperStruct, Tree
      #maybe others i don't know? sparse array/sparse matrix?
      #ordered hashes?
        case obj
        when nil: #do nothing
        when (Set if defined? Set),(WeakRefSet if defined? WeakRefSet):
          obj.each{|elem|
            yield(obj,elem, elem, GraphEdge::SetMember)
          }
        when Struct:
          obj.members.each{|mem|
            yield(obj,obj[mem],mem, GraphEdge::BracketsValue)
          }
        when Hash:
          obj.each{|(i,elem)| 
            yield(obj,elem,i, GraphEdge::HashValue)          
            yield(obj,i,i, GraphEdge::HashKey)
          }
        when Array:
          obj.each_with_index{|elem,i| 
            yield(obj,elem,i, GraphEdge::Array)
          }
        when Range:
          yield(obj,obj.first, :first, GraphEdge::ObjectMethValue)
          yield(obj,obj.last, :last, GraphEdge::ObjectMethValue)        
        #when RBTree:  huh
        when (ActiveRecord::Base if defined? ActiveRecord::Base): 
          obj.columns.each{|mem|
            yield(obj,obj[mem],mem, GraphEdge::BracketsValue)
          }
        end
         #traverse instance vars in any case
          obj.instance_variables.each{|var|
            yield obj, (obj.instance_variable_get var), var, GraphEdge::ObjectIvarValue
          }
      end
      
          
      #---------------------------
        #wannabe in class ::Array
      def recursive_each arr,&block
        arr.each {|item|
          if item.respond_to? :to_a
            recursive_each item.to_a, &block
          else
            block[item]
          end
        }
      end
      
      #---------------------------
      def recursive_reverse_each arr,&block
        arr.reverse_each {|item|
          if item.respond_to? :to_ary
            recursive_reverse_each item.to_ary, &block
          else
            block[item]
          end
        }
      end

    end
  end
  
  #--------------------------------
  #represents an edge along the ruby object graph. (Container and position within it.)
  class GraphEdge 
    class ContextWasRecycled < Exception; end
    def initialize(context,index,len=1,&newval_code)
      assert len>=0
      @context,@index,@len,@newval_code=context,index,len,newval_code
      ObjectSpace.define_finalizer(@context,(method :context_died))
    end
    attr_reader :index,:len,:context
    
#    def new_value_set!(&nv) @newval_code=nv end
    def context_type; self.class end
    
    def call; replace; end
    
    def context_died
      @context=nil
    end
    
    def new_value
      @newval_code[self]
    end
  
    #--------------------------------
    class Array<GraphEdge
      def initialize(context,index,len=1)
        super
        
        if Range===@index 
          @len=@index.last-@index.first
          @len-=1 if @len.exclude_end?
          @index=@index.first
        end
      end

      def old_value
        context[@index]
      end
      
      def replace(*newvals)
        newvals.empty? and newvals=[new_value]
        context[@index]=*newvals
      end
    end

    #--------------------------------
    class BracketsKey < GraphEdge
      def old_value
        @index
      end
      #@index is actually a list... so is newkey
      def replace(*newkey)
        newkey.empty? and newkey=[new_value]
        context[*newkey]=context.delete(*@index)
      end  
    end
    
    #--------------------------------
    class BracketsValue < GraphEdge
      def old_value
        context[*@index]
      end
      #@index is actually a list    
      def replace(newval=new_value)
        context[*@index]=newval
      end
    end
    
    #--------------------------------
    class HashKey<GraphEdge
      def old_value
        @index
      end
      
      def replace(newkey=new_value)
        context[newkey]=context.delete @index
      end
    end
    
    #--------------------------------
    class HashValue<GraphEdge
      def old_value
        context[@index]
      end
      
      def replace(newval=new_value)
        context[@index]=newval
      end
    end

    #--------------------------------
    class SetMember<GraphEdge
      def old_value
        @index
      end
      
      def replace(newval=new_value)
        context.delete @index
        context<<newval
      end
    end
    
    #--------------------------------
    class HashDefaultValue<GraphEdge
      def initialize(context,index=nil,len=1)
        super
      end
      def old_value
        context.default @index
      end
      
      def replace(newval=nil)
        raise TypeError
      end
  #    def new_value_set!; nil end
  #    remove_method :new_value_set!
    end
    
   #--------------------------------
    class HashDefaultKey<GraphEdge
      def initialize(context,index=nil,len=1)
        super
      end
      def old_value
        nil
      end
      
      def replace(newval=nil)
        raise TypeError
      end
  #    def new_value_set!; nil end
  #    remove_method :new_value_set!
    end
    
    #--------------------------------
    class ObjectName<GraphEdge
      def initialize(context,index,len=1)
        super
      end
      def old_value
        @index
      end
      
      def replace(newval=nil)
        raise TypeError
      end
  #    def new_value_set!; nil end
  #    remove_method :new_value_set!
    end

    #--------------------------------
    class ObjectIvarValue<GraphEdge
      def old_value
        context.instance_variable_get @index
      end
      
      def replace(newval=new_value)
        context.instance_variable_set(@index, newval)
      end
    end
    
    #--------------------------------
    class ObjectMethValue<GraphEdge
      def old_value
        if ::Array===@index
          if Proc===@index.last then 
            block=context.pop
          elsif Literal===@index.last then 
            @index[-1]=@index[-1].unlit
          end
          context.send(*@index, &block)
        else
          context.send @index
        end
      end
      
      def replace(newval=new_value)
        raise TypeError if ::Array===@index    
        context.send "#{@index}=", newval
      end
    end
    
    #--------------------------------
    class TopLevel<GraphEdge
      def initialize(context,index=nil,len=1,&newval_code)
        super
      end
      
      def old_value
        context
      end
      
      def replace(newval=new_value)
        huh #can't really replace values in toplevel context...???
      end
    
    end
    
    
  end
  
end
