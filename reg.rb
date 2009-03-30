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
require 'regcore'
require 'reglogic'
require 'reghash'
require 'regarray'
require 'regrepeat'
require 'regsubseq'
#require 'regarrayold' #old bt engine
require 'regprogress' #new bt engine
#enable one engine or the other, but not both

require 'regevent'
require 'regbind'
require 'regreplace'
require 'regbackref'
require 'regitem_that'
require 'regknows'
require 'regsugar'
require 'regvar'
require 'regposition'
require 'regold'  #will go away

require 'regcompiler' #engine, bah
2+2
#Kernel.instance_eval( &Reg::TLA_pirate)
