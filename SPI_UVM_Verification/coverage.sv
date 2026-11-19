// Functional coverage, written from the plan in README.md (section "Coverage plan").
// Every bin below maps to a feature in the plan; nothing is auto-binned.
class spi_coverage extends uvm_subscriber#(spi_transaction);
  
  `uvm_component_utils(spi_coverage)

  uvm_analysis_imp#(spi_transaction, spi_coverage) cov_imp;
  spi_transaction tr;

  // Plan-bin hit counters. They mirror x_op_addr, x_op_err and cp_din so the
  // closure number can be reported on simulators that ignore covergroups
  // (Verilator 5 parses covergroups but does not collect them).
  int unsigned wr_hit[32], rd_hit[32];
  int unsigned wr_illegal, rd_illegal, wr_err, rd_err;
  int unsigned din_zero, din_ones, din_alt;
  int unsigned mode_op[4][2];          // [mode][wr] for legal transfers
  int unsigned div_min, div_max, err_div;

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cov_imp = new("cov_imp", this);
  endfunction
  


    covergroup check;
        option.per_instance = 1;

        // F1/F2: both directions
        cp_op : coverpoint tr.wr {
            bins write = {1};
            bins read  = {0};
        }

        // F3/F4: every legal location, plus the illegal range as one bin
        cp_addr : coverpoint tr.addr {
            bins legal[]  = {[0:31]};
            bins illegal  = {[32:255]};
        }

        // F5: data corners matter for a bit-serial shifter (all 0s, all 1s, alternating)
        cp_din : coverpoint tr.din iff (tr.wr) {
            bins zero     = {8'h00};
            bins ones     = {8'hFF};
            bins alt      = {8'h55, 8'hAA};
            bins others   = default;
        }

        // F6: error response
        cp_err : coverpoint tr.err {
            bins ok  = {0};
            bins err = {1};
        }

        // F10: all four SPI modes
        cp_mode : coverpoint {tr.cpol, tr.cpha} iff (!tr.err) {
            bins mode0 = {2'b00};
            bins mode1 = {2'b01};
            bins mode2 = {2'b10};
            bins mode3 = {2'b11};
        }

        // F11: SCLK divider corners (fastest and slowest legal SCLK) and illegal values
        cp_div : coverpoint tr.clk_div {
            bins fastest = {4};
            bins mid     = {[5:14]};
            bins slowest = {15};
            bins illegal = {[0:3]};
        }

        // Every legal address written AND read; illegal range hit in both directions
        x_op_addr : cross cp_op, cp_addr;

        // Write and read in every mode
        x_op_mode : cross cp_op, cp_mode;

        // Error seen on both a write and a read
        x_op_err  : cross cp_op, cp_err;
    endgroup
  
    function new(string name = "spi_coverage", uvm_component parent = null);
    super.new(name, parent);
   check = new();
  endfunction
  

    virtual function void write(spi_transaction t);
        // Reset items carry no address/data; sampling them would hit bins with stale values.
        if (t.op == rstdut) return;
        tr = t;
        check.sample();
        if (t.addr < 32 && !t.err) begin
          if (t.wr) wr_hit[t.addr]++; else rd_hit[t.addr]++;
        end
        else if (t.addr >= 32) begin
          if (t.wr) wr_illegal++; else rd_illegal++;
        end
        if (t.err) begin
          if (t.wr) wr_err++; else rd_err++;
        end
        if (!t.err) mode_op[{t.cpol, t.cpha}][t.wr]++;
        if (!t.err && t.clk_div == 4)  div_min++;
        if (!t.err && t.clk_div == 15) div_max++;
        if (t.clk_div < 4 && t.addr < 32) err_div++;
        if (t.wr && t.addr < 32) begin
          if (t.din == 8'h00) din_zero++;
          if (t.din == 8'hFF) din_ones++;
          if (t.din inside {8'h55, 8'hAA}) din_alt++;
        end
    endfunction

    virtual function void report_phase(uvm_phase phase);
        int unsigned hit = 0, total = 0;
        string missed = "";
        super.report_phase(phase);
        foreach (wr_hit[a]) begin
          total += 2;
          if (wr_hit[a]) hit++; else missed = {missed, $sformatf(" wr@%0d", a)};
          if (rd_hit[a]) hit++; else missed = {missed, $sformatf(" rd@%0d", a)};
        end
        foreach (mode_op[m, w]) begin
          total++;
          if (mode_op[m][w]) hit++; else missed = {missed, $sformatf(" %s@mode%0d", w ? "wr" : "rd", m)};
        end
        total += 10;
        if (div_min)    hit++; else missed = {missed, " div=4"};
        if (div_max)    hit++; else missed = {missed, " div=15"};
        if (err_div)    hit++; else missed = {missed, " err_div"};
        if (wr_illegal) hit++; else missed = {missed, " wr@illegal"};
        if (rd_illegal) hit++; else missed = {missed, " rd@illegal"};
        if (wr_err)     hit++; else missed = {missed, " wr_err"};
        if (rd_err)     hit++; else missed = {missed, " rd_err"};
        if (din_zero)   hit++; else missed = {missed, " din=00"};
        if (din_ones)   hit++; else missed = {missed, " din=FF"};
        if (din_alt)    hit++; else missed = {missed, " din=55/AA"};
`ifndef VERILATOR
        `uvm_info("COV", $sformatf("Covergroup (simulator-reported): %0.2f%%", check.get_inst_coverage()), UVM_NONE)
`endif
        `uvm_info("COV", $sformatf("Plan bins hit: %0d/%0d (%0.1f%%)%s", hit, total, 100.0*hit/total,
                                   missed == "" ? "" : {"  MISSED:", missed}), UVM_NONE)
    endfunction
  
endclass
