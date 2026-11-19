`uvm_analysis_imp_decl(_ser)

class sco extends uvm_scoreboard;
`uvm_component_utils(sco)

  uvm_analysis_imp#(spi_transaction,sco) recv;          // parallel side (request + response)
  uvm_analysis_imp_ser#(spi_serial_item,sco) ser_recv;  // SPI pins (one item per CS-low window)
  spi_serial_item ser_q[$];                             // frames waiting for their request
  bit [7:0] arr[32] = '{default:0};   // reference model of the 32 x 8 slave memory
  bit [7:0] data_rd = 0;

  // Counters so the end-of-test report can say what was actually checked
  int unsigned n_writes     = 0;
  int unsigned n_reads_ok   = 0;
  int unsigned n_mismatch   = 0;
  int unsigned n_err_ok     = 0;   // err correctly raised for an illegal address
  int unsigned n_err_bad    = 0;   // err raised/missing when it should not be
  int unsigned n_resets     = 0;
  int unsigned n_frames_ok  = 0;   // SPI frames that matched the request bit for bit
  int unsigned n_frame_bad  = 0;

    function new(input string inst = "sco", uvm_component parent = null);
    super.new(inst,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    recv = new("recv", this);
    ser_recv = new("ser_recv", this);
    endfunction


  virtual function void write(spi_transaction tr);
    bit exp_err;

    if(tr.op == rstdut)
      begin
        // Slave memory is NOT cleared by reset in this RTL, so the reference array is kept.
        n_resets++;
        ser_q.delete();
        `uvm_info("SCO", "SYSTEM RESET DETECTED (reference memory retained)", UVM_HIGH);
        return;
      end

    // Spec: only addresses 0..31 exist and the divider must be 4..15.
    // Anything else must end with err = 1 and no SPI frame.
    exp_err = (tr.addr > 31) || (tr.clk_div < 4);
    if (tr.err != exp_err)
      begin
        n_err_bad++;
        `uvm_error("SCO", $sformatf("ERR FLAG MISMATCH : op:%s addr:%0d err:%0d expected:%0d",
                                    tr.op.name(), tr.addr, tr.err, exp_err))
        return;
      end

    if (exp_err)
      begin
        if (ser_q.size() != 0)
          `uvm_error("SCO", $sformatf("CS asserted for a rejected request: %s", ser_q.pop_front().convert2string()))
        n_err_ok++;
        `uvm_info("SCO", $sformatf("SLV ERROR as expected : op:%s addr:%0d", tr.op.name(), tr.addr), UVM_HIGH);
        return;
      end

    check_frame(tr);

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

  // SPI frames arrive when CS rises, one cycle before done, so the frame for a
  // request is always queued by the time the request's response arrives.
  virtual function void write_ser(spi_serial_item it);
    ser_q.push_back(it);
  endfunction

  // The frame on the pins must carry exactly what the request asked for, in
  // the requested mode; on a read the slave's MISO byte must equal the model.
  function void check_frame(spi_transaction tr);
    spi_serial_item f;
    string why = "";
    if (ser_q.size() == 0) begin
      n_frame_bad++;
      `uvm_error("SCO", $sformatf("No SPI frame seen for %s addr:%0d", tr.op.name(), tr.addr))
      return;
    end
    f = ser_q.pop_front();
    if (f.nbits != 16)                    why = {why, $sformatf(" bits=%0d(exp 16)", f.nbits)};
    if ({f.cpol, f.cpha} != {tr.cpol, tr.cpha}) why = {why, " mode"};
    if (f.wr() != tr.wr)                  why = {why, " wr"};
    if (f.addr() != tr.addr[4:0])         why = {why, " addr"};
    if (tr.wr && f.wdata() != tr.din)     why = {why, $sformatf(" mosi_data=%0d(exp %0d)", f.wdata(), tr.din)};
    if (!tr.wr && f.rdata() != arr[tr.addr]) why = {why, $sformatf(" miso_data=%0d(exp %0d)", f.rdata(), arr[tr.addr])};
    if (why == "") n_frames_ok++;
    else begin
      n_frame_bad++;
      `uvm_error("SCO", $sformatf("SPI FRAME MISMATCH:%s | frame %s", why, f.convert2string()))
    end
  endfunction

  // A test that compared nothing must not be reported as a pass.
  virtual function void check_phase(uvm_phase phase);
    super.check_phase(phase);
    if (n_reads_ok + n_mismatch == 0)
      `uvm_error("SCO", "No read data was compared during the test")
    if (ser_q.size() != 0)
      `uvm_error("SCO", $sformatf("%0d SPI frame(s) seen with no matching request", ser_q.size()))
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SCO", $sformatf("SUMMARY writes:%0d reads_matched:%0d mismatches:%0d err_expected_ok:%0d err_flag_bad:%0d resets:%0d spi_frames_ok:%0d spi_frames_bad:%0d",
                               n_writes, n_reads_ok, n_mismatch, n_err_ok, n_err_bad, n_resets, n_frames_ok, n_frame_bad), UVM_NONE)
  endfunction

endclass
