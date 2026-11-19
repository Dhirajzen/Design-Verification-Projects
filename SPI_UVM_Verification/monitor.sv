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
      else if (vif.start)
         begin
          // The request is captured on the start pulse (the DUT latches it on
          // the same edge); the response is captured when done rises.
          tr.wr      = vif.wr;
          tr.op      = vif.wr ? writed : readd;
          tr.din     = vif.din;
          tr.addr    = vif.addr;
          tr.cpol    = vif.cpol;
          tr.cpha    = vif.cpha;
          tr.clk_div = vif.clk_div;
          @(posedge vif.done);
          tr.err     = vif.err;
          tr.dout    = vif.dout;
          `uvm_info("MON", $sformatf("DATA %s addr:%0d wdata:%0d rdata:%0d err:%0d mode:%0d div:%0d",
                                     tr.wr ? "WRITE" : "READ", tr.addr, tr.din, tr.dout, tr.err,
                                     {tr.cpol, tr.cpha}, tr.clk_div), UVM_MEDIUM);
          send.write(tr);
         end
    end
   endtask

endclass
