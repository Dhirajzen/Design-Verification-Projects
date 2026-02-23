
interface apb_if;
  logic pclk; //clock 
  logic prst; // negative reset
  logic psel; // select line each peripheral have its own select line master set psel high while communicating with slave 
  logic [7:0] paddr; // address line master put address of slave, if slave consisits of multiple reg we can access specific reg with this addr
  logic [7:0] pwdata; // the data master wants to write on slave
  logic penable; // enable line set high on next clock cycle when master is ready to send / recive data
  logic pwrite;// set high while write operation / LOW on read operation
  logic [7:0] prdata; // read data from slave 
  logic pready; // becomes high when slave is ready to accept new data (in this zero wait state assuming slave is always ready to accept data)
  logic   pslverr;
  
  //event signals
  event drvdone; // this event is used to signal from the driver that a drive operation has concluded
  event mondone; // this event is used to signal from the monitor that a monitoring operation has concluded
    


  // APB HANDSHAKE / TIMING ASSERTIONS

  // Clocking for SVA
  default clocking cb @(posedge pclk); endclocking
  default disable iff (!prst);

  // A1) PENABLE can only be high when PSEL is high (ACCESS implies selected)
  apb_penable_implies_psel: assert property (penable |-> psel)
    else $error("APB: PENABLE high without PSEL");

  // A2) PENABLE only rises after a SETUP cycle (i.e., previous cycle had PSEL=1 and PENABLE=0)
  apb_enable_after_setup: assert property ($rose(penable) |-> ($past(psel) && !$past(penable)))
    else $error("APB: PENABLE rose without prior SETUP (PSEL=1,PENABLE=0)");

  // A3) Once a transfer starts (PSEL high), keep control/address stable until transfer completes (PREADY handshake)
  // Transfer completes when in ACCESS and PREADY=1
  sequence apb_wait;
    psel && penable && !pready;
  endsequence

  apb_stable_while_wait: assert property (
    apb_wait |=> ($stable(paddr) && $stable(pwrite) && $stable(pwdata) && $stable(psel) && $stable(penable))
  ) else $error("APB: Signals changed while waiting for PREADY");

  // A4) If slave is 0-wait (design usually responds immediately), then ACCESS completes in 1 cycle.
  // If you truly want to allow wait states, comment this out.
  apb_zero_wait: assert property (
    (psel && penable) |-> pready
  ) else $error("APB: Expected zero-wait response but PREADY low in ACCESS");

  // A5) PSLVERR is only meaningful in ACCESS phase; must be low otherwise
  apb_pslverr_only_in_access: assert property (
    pslverr |-> (psel && penable)
  ) else $error("APB: PSLVERR asserted outside ACCESS");

  // A7) Read data should be stable during ACCESS when waiting for PREADY
  apb_prdata_stable_while_wait: assert property (
    (psel && penable && !pready && !pwrite) |=> $stable(prdata)
  ) else $error("APB: PRDATA changed during ACCESS wait");

  // A8) End of transfer behavior: after completion, PENABLE should drop next cycle (go back to SETUP or IDLE)
  apb_penable_drops_after_complete: assert property (
    (psel && penable && pready) |=> !penable
  ) else $error("APB: PENABLE did not drop after transfer completion");
  
endinterface
    
  