// Protocol checker bound into the SPI master (spi_intf). It sees the SPI pins
// and the master's latched mode (cpol_q/cpha_q) without touching the RTL.
// Failures are reported with uvm_error so they fail the UVM test.
`include "uvm_macros.svh"

module spi_checker (
  input logic       clk, rst,
  input logic       start, wr,
  input logic [7:0] addr,
  input logic [3:0] clk_div,
  input logic       cpol, cpha,       // mode pins (request side)
  input logic       cpol_q, cpha_q,   // mode latched by the master for this frame
  input logic       cs,               // chip select, active low
  input logic       sclk, mosi,
  input logic       done, err
);
  import uvm_pkg::*;

  // Longest legal frame: setup + 32 edges + hold, all at clk_div = 15
  localparam int MAX_FRAME_CYCLES = 600;

  // ---- helper logic: SCLK edges, classified by the latched mode ----
  logic       sclk_d;
  logic [6:0] edges;                  // SCLK edges in the current CS-low window
  always_ff @(posedge clk) begin
    sclk_d <= sclk;
    if (rst || $fell(cs)) edges <= '0;
    else if (!cs && sclk != sclk_d) edges <= edges + 1;
  end
  wire sclk_toggles = (sclk != sclk_d);
  wire lead_edge    = sclk_toggles && (sclk != cpol_q);   // leaving the idle level
  wire sample_edge  = cpha_q ? (sclk_toggles && !lead_edge) : lead_edge;

  default clocking cb @(posedge clk); endclocking
  default disable iff (rst);

  // ---- request / response ----
  // A rejected request (illegal address or divider) never selects the slave
  a_err_without_cs: assert property (err |-> cs)
    else `uvm_error("SVA", "err asserted while chip select was low")

  // err only for addr > 31 or clk_div < 4
  a_err_only_illegal: assert property (err |-> (addr > 31 || clk_div < 4))
    else `uvm_error("SVA", $sformatf("err asserted for a legal request addr:%0d div:%0d", addr, clk_div))

  // done is not reported while the slave is still selected
  a_done_cs_high: assert property (done |-> cs)
    else `uvm_error("SVA", "done asserted while chip select was still low")

  // ---- SPI timing ----
  // SCLK sits at the CPOL idle level whenever CS is high
  a_sclk_idle: assert property (cs |-> sclk == cpol_q)
    else `uvm_error("SVA", $sformatf("SCLK=%0d with CS high, CPOL=%0d", sclk, cpol_q))

  // No SCLK edge in the same cycle CS falls or rises (setup and hold)
  a_no_edge_at_cs: assert property (($fell(cs) || $rose(cs)) |-> !sclk_toggles)
    else `uvm_error("SVA", "SCLK edge in the same cycle as a CS edge")

  // MOSI never changes on a sample edge (the slave would latch a moving bit)
  a_mosi_stable_on_sample: assert property ((!cs && sample_edge) |-> $stable(mosi))
    else `uvm_error("SVA", "MOSI changed on a sample edge")

  // CPHA = 0: the first bit (wr) is already on MOSI when CS falls
  a_cpha0_first_bit: assert property (($fell(cs) && !cpha_q) |-> mosi == wr)
    else `uvm_error("SVA", "CPHA=0 frame started without the first bit on MOSI")

  // Exactly 16 SCLK cycles (32 edges) per frame
  a_16_clocks: assert property ($rose(cs) |-> edges == 32)
    else `uvm_error("SVA", $sformatf("frame had %0d SCLK edges, expected 32", edges))

  // Every chip-select window closes within a bounded time (no stuck frame)
  a_cs_window_bounded: assert property ($fell(cs) |-> ##[1:MAX_FRAME_CYCLES] cs)
    else `uvm_error("SVA", "chip select stayed low for too long")

  // The requester must hold the mode and divider stable while a frame is in flight
  a_mode_stable: assert property (!cs |-> $stable({cpol, cpha, clk_div}))
    else `uvm_error("SVA", "cpol/cpha/clk_div changed during a frame")

  // ---- coverage of the scenarios the checker is meant to see ----
  c_mode0_frame : cover property ($fell(cs) && !cpol_q && !cpha_q);
  c_mode1_frame : cover property ($fell(cs) && !cpol_q &&  cpha_q);
  c_mode2_frame : cover property ($fell(cs) &&  cpol_q && !cpha_q);
  c_mode3_frame : cover property ($fell(cs) &&  cpol_q &&  cpha_q);
  c_error       : cover property ($rose(err));
endmodule

bind spi_intf spi_checker chk (
  .clk, .rst, .start, .wr, .addr, .clk_div, .cpol, .cpha,
  .cpol_q, .cpha_q, .cs, .sclk, .mosi, .done, .err
);
