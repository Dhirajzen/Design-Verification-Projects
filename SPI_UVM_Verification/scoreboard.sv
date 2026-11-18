class sco extends uvm_scoreboard;
`uvm_component_utils(sco)

  uvm_analysis_imp#(spi_transaction,sco) recv;
  bit [7:0] arr[32] = '{default:0};   // reference model of the 32 x 8 slave memory
  bit [7:0] data_rd = 0;

  // Counters so the end-of-test report can say what was actually checked
  int unsigned n_writes     = 0;
  int unsigned n_reads_ok   = 0;
  int unsigned n_mismatch   = 0;
  int unsigned n_err_ok     = 0;   // err correctly raised for an illegal address
  int unsigned n_err_bad    = 0;   // err raised/missing when it should not be
  int unsigned n_resets     = 0;

    function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
    endfunction


  virtual function void write(spi_transaction tr);
    bit exp_err;

    if(tr.op == rstdut)
      begin
        // Slave memory is NOT cleared by reset in this RTL, so the reference array is kept.
        n_resets++;
        `uvm_info("SCO", "SYSTEM RESET DETECTED (reference memory retained)", UVM_HIGH);
        return;
      end

    // Spec: only addresses 0..31 exist. Anything above must end with err = 1.
    exp_err = (tr.addr > 31);
    if (tr.err != exp_err)
      begin
        n_err_bad++;
        `uvm_error("SCO", $sformatf("ERR FLAG MISMATCH : op:%s addr:%0d err:%0d expected:%0d",
                                    tr.op.name(), tr.addr, tr.err, exp_err))
        return;
      end

    if (exp_err)
      begin
        n_err_ok++;
        `uvm_info("SCO", $sformatf("SLV ERROR as expected : op:%s addr:%0d", tr.op.name(), tr.addr), UVM_HIGH);
        return;
      end

    if (tr.op == writed)
      begin
        arr[tr.addr] = tr.din;
        n_writes++;
        `uvm_info("SCO", $sformatf("DATA WRITE OP  addr:%0d, wdata:%0d", tr.addr, tr.din), UVM_HIGH);
      end
    else if (tr.op == readd)
      begin
        data_rd = arr[tr.addr];
        if (data_rd == tr.dout)
          begin
            n_reads_ok++;
            `uvm_info("SCO", $sformatf("DATA MATCHED : addr:%0d, rdata:%0d", tr.addr, tr.dout), UVM_HIGH)
          end
        else
          begin
            n_mismatch++;
            // uvm_error (not uvm_info) so a mismatch actually fails the test
            `uvm_error("SCO", $sformatf("DATA MISMATCH : addr:%0d, rdata:%0d expected:%0d", tr.addr, tr.dout, data_rd))
          end
      end
  endfunction

  // A test that compared nothing must not be reported as a pass.
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (n_reads_ok + n_mismatch == 0)
      `uvm_error("SCO", "No read data was compared during the test")
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCO", $sformatf("SUMMARY writes:%0d reads_matched:%0d mismatches:%0d err_expected_ok:%0d err_flag_bad:%0d resets:%0d",
                               n_writes, n_reads_ok, n_mismatch, n_err_ok, n_err_bad, n_resets), UVM_NONE)
  endfunction

endclass
