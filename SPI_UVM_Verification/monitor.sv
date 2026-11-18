class mon extends uvm_monitor;
`uvm_component_utils(mon)

uvm_analysis_port#(spi_transaction) send;
virtual spi_i vif;

    function new(input string inst = "mon", uvm_component parent = null);
    super.new(inst,parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    send = new("send", this);
      if(!uvm_config_db#(virtual spi_i)::get(this,"","vif",vif))//uvm_test_top.env.agent.drv.aif
        `uvm_fatal("MON","Unable to access Interface");
    endfunction


    virtual task run_phase(uvm_phase phase);
    spi_transaction tr;
    forever begin
      @(posedge vif.clk);
      // A fresh object per observed transfer. Reusing one handle means every
      // subscriber that stored the previous item sees it overwritten.
      tr = spi_transaction::type_id::create("tr");
      if(vif.rst)
        begin
        tr.op      = rstdut;
        `uvm_info("MON", "SYSTEM RESET DETECTED", UVM_HIGH);
        send.write(tr);
        end
      else
         begin
          @(posedge vif.done);
          // Classify the operation when it completes, not when it starts:
          // at the start wr can still hold the previous item's value.
          tr.wr     = vif.wr;
          tr.op     = vif.wr ? writed : readd;
          tr.din    = vif.din;
          tr.addr   = vif.addr;
          tr.err    = vif.err;
          tr.dout   = vif.dout;
          `uvm_info("MON", $sformatf("DATA %s addr:%0d wdata:%0d rdata:%0d err:%0d",
                                     tr.wr ? "WRITE" : "READ", tr.addr, tr.din, tr.dout, tr.err), UVM_MEDIUM);
          send.write(tr);
         end
    end
   endtask

endclass
