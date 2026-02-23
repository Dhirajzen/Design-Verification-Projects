
// the DUT interface
interface spi_i;
  logic clk;
  logic rst;
  logic wr;
  logic [7:0] din;
  logic [7:0] addr;
  logic done;
  logic err;
  logic [7:0] dout;

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

// done is a 1-cycle pulse
a_done_one_pulse: assert property (done |=> !done)
  else $error("SPI: done is not a 1-cycle pulse");

// err implies done (your RTL sets both in error)
a_err_implies_done: assert property (err |-> done)
  else $error("SPI: err asserted without done");

// done/err only when cs is high (true in your RTL)
a_done_only_when_cs_high: assert property (done |-> cs)
  else $error("SPI: done asserted while cs low");

a_err_only_when_cs_high: assert property (err |-> cs)
  else $error("SPI: err asserted while cs low");

// ready is a 1-cycle pulse (mem does ready<=1 then clears in send_data)
a_ready_one_pulse: assert property ($rose(ready) |=> !ready)
  else $error("SPI: ready is not a 1-cycle pulse");

// op_done is a 1-cycle pulse (mem asserts then returns to idle)
a_op_done_one_pulse: assert property ($rose(op_done) |=> !op_done)
  else $error("SPI: op_done is not a 1-cycle pulse");

  
endinterface