
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


endinterface