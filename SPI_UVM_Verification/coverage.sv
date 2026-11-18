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

        // Every legal address written AND read; illegal range hit in both directions
        x_op_addr : cross cp_op, cp_addr;

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
        if (t.addr < 32) begin
          if (t.wr) wr_hit[t.addr]++; else rd_hit[t.addr]++;
        end
        else begin
          if (t.wr) wr_illegal++; else rd_illegal++;
        end
        if (t.err) begin
          if (t.wr) wr_err++; else rd_err++;
        end
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
        total += 7;
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
