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