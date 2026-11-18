// Protocol checker bound into the SPI master (spi_intf) so it can see the
// internal chip-select and handshake signals without touching the RTL.
// Failures are reported with uvm_error so they fail the UVM test.
`include "uvm_macros.svh"

module spi_checker (
  input logic       clk, rst,
  input logic       wr,
  input logic [7:0] addr,
  input logic       cs,        // chip select to the slave, active low
  input logic       ready,     // slave -> master: read data is about to be shifted out
  input logic       op_done,   // slave -> master: slave finished the operation
  input logic       done, err  // master -> testbench
);
  import uvm_pkg::*;

  localparam int MAX_FRAME_CYCLES = 40;  // write frame is 17 bits, read address phase 9 bits

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  // An illegal address must be rejected without ever selecting the slave
  a_err_without_cs: assert property (err |-> cs)
    else `uvm_error("SVA", "err asserted while chip select was low")

  // err is only legal for addresses outside 0..31
  a_err_only_illegal: assert property (err |-> addr > 31)
    else `uvm_error("SVA", $sformatf("err asserted for legal address %0d", addr))

  // done must not be reported while the slave is still selected
  a_done_cs_high: assert property (done |-> cs)
    else `uvm_error("SVA", "done asserted while chip select was still low")

  // Every chip-select window closes within a bounded number of cycles (no stuck frame)
  a_cs_window_bounded: assert property ($fell(cs) |-> ##[1:MAX_FRAME_CYCLES] cs)
    else `uvm_error("SVA", "chip select stayed low for too long")

  // Coverage of the protocol scenarios the checker is meant to see
  c_write_frame : cover property ($fell(cs) &&  wr);
  c_read_frame  : cover property ($fell(cs) && !wr);
  c_read_ready  : cover property ($rose(ready));
  c_error       : cover property ($rose(err));
endmodule

bind spi_intf spi_checker chk (.*);
