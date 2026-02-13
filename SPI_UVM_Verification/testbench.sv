// Code your testbench here
// or browse Examples
// In Vivado 2022 don't include this line. On EdaPlaygrounds do.
import uvm_pkg::*; 
`include "uvm_macros.svh"

`include "test.sv"
`include "interface.sv"

module tb;
  
  
  spi_i vif();
  
  top dut (.wr(vif.wr), .clk(vif.clk), .rst(vif.rst), .addr(vif.addr), .din(vif.din), .dout(vif.dout), .done(vif.done), .err(vif.err));
  
  initial begin
    vif.clk <= 0;
  end
 
  always #10 vif.clk <= ~vif.clk;
 
  
  
  initial begin
    uvm_config_db#(virtual spi_i)::set(null, "*", "vif", vif);
    run_test("test");
   end
  
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
 
  
endmodule