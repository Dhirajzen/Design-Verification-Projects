class driver extends uvm_driver #(spi_transaction);
  `uvm_component_utils(driver)
  
  virtual spi_i vif;
  spi_transaction tr;
  int unsigned done_timeout_cycles = 2000;  // longest legal frame is ~530 cycles (div 15)
  
  
  function new(input string path = "drv", uvm_component parent = null);
    super.new(path,parent);
  endfunction
  
 virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
     tr = spi_transaction::type_id::create("tr");
      
      if(!uvm_config_db#(virtual spi_i)::get(this,"","vif",vif))//uvm_test_top.env.agent.drv.aif
      `uvm_fatal("DRV","Unable to access Interface");
  endfunction
  
  
  
  task reset_dut();
 
    repeat(5) 
    begin
    vif.rst      <= 1'b1;  ///active high reset
    vif.addr     <= 'h0;
    vif.din      <= 'h0;
    vif.wr       <= 1'b0; 
    vif.start    <= 1'b0;
    vif.cpol     <= 1'b0;
    vif.cpha     <= 1'b0;
    vif.clk_div  <= 4'd4;
   `uvm_info("DRV", "System Reset : Start of Simulation", UVM_MEDIUM);
    @(posedge vif.clk);
      end
  endtask
  
  // Wait for done, but never forever: if the DUT hangs, fail this test now
  // with a clear message instead of letting the regression hit its wall-clock limit.
  task wait_done();
    fork
      @(posedge vif.done);
      begin
        repeat(done_timeout_cycles) @(posedge vif.clk);
        `uvm_fatal("DRV", $sformatf("TIMEOUT: done not seen within %0d cycles (op:%s addr:%0d)",
                                    done_timeout_cycles, tr.op.name(), tr.addr))
      end
    join_any
    disable fork;
  endtask

  // One request: put command, data and SPI mode on the pins, pulse start for
  // one cycle, and hold everything stable until done (the DUT's rule).
  task drive_request();
    vif.rst     <= 1'b0;
    vif.wr      <= (tr.op == writed);
    vif.addr    <= tr.addr;
    vif.din     <= tr.din;
    vif.cpol    <= tr.cpol;
    vif.cpha    <= tr.cpha;
    vif.clk_div <= tr.clk_div;
    vif.start   <= 1'b1;
    @(posedge vif.clk);
    vif.start   <= 1'b0;
    `uvm_info("DRV", $sformatf("%s addr:%0d din:%0d mode:%0d div:%0d", tr.op.name(), tr.addr, tr.din,
                               {tr.cpol, tr.cpha}, tr.clk_div), UVM_MEDIUM);
    wait_done();
  endtask

  task drive();
    reset_dut();
   forever begin
     
         seq_item_port.get_next_item(tr);
     
     
                   if(tr.op ==  rstdut)
                          begin
                          vif.rst   <= 1'b1;
                          vif.start <= 1'b0;
                          @(posedge vif.clk);  
                          end
 
                  else if(tr.op == writed || tr.op == readd)
                          drive_request();
       seq_item_port.item_done();
     
   end
  endtask
  
 
  virtual task run_phase(uvm_phase phase);
    drive();
  endtask
 
  
endclass