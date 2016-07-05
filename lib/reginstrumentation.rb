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
require 'instrument'
require 'reg'

Instrument.on_entry_to(Reg::Progress, :bt_match, "args[0]||matcher")
Instrument.on_exit_from(Reg::Progress, :bt_match)

Instrument.on_entry_to(Reg::Progress, :last_next_match,
  "args[0].matcher", "args[0].regsidx", "args[0].cursor.pos", "(args[0]||context).position_inc_stack")
Instrument.on_exit_from(Reg::Progress, :last_next_match, "(args[0] || context).position_inc_stack")

Instrument.on_entry_to(Reg::RepeatMatchSet, :next_match, :@consumed, "@context.matcher", "@context.position_inc_stack")
Instrument.on_exit_from(Reg::RepeatMatchSet, :next_match, "@context.position_inc_stack")

Instrument.on_entry_to(Reg::SubseqMatchSet, :next_match)
Instrument.on_exit_from(Reg::SubseqMatchSet, :next_match)

Instrument.on_entry_to(Reg::Progress, :backtrack, :position_stack, :position_inc_stack, "(args[0] || context).regsidx", "(args[0] || context).matcher")
Instrument.on_exit_from(Reg::Progress, :backtrack)
