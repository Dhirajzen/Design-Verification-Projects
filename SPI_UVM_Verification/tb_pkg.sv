package tb_pkg;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

typedef enum bit [2:0]   {readd = 0, writed = 1, rstdut = 2, writeerr = 3, readerr = 4} oper_mode;
 
  // Put shared typedefs/classes EARLY.
  // If your enum/transaction/config are currently in config.sv, that's fine.
  `include "config.sv"

  // Build blocks that depend on transaction/config
  `include "sequencer.sv"
  `include "driver.sv"
  `include "monitor.sv"
  `include "scoreboard.sv"
  `include "coverage.sv"
  
  // Agent/env/test on top
  `include "agent.sv"
  `include "env.sv"
  `include "test.sv"
  

endpackage