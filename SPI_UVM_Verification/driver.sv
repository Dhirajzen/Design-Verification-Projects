class driver extends uvm_driver #(spi_transaction);
  `uvm_component_utils(driver)
  
  virtual spi_i vif;
  spi_transaction tr;
  int unsigned done_timeout_cycles = 1000;  // a normal transfer takes ~25 cycles
  
  
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

  task drive();
    reset_dut();
   forever begin
     
         seq_item_port.get_next_item(tr);
     
     
                   if(tr.op ==  rstdut)
                          begin
                          vif.rst   <= 1'b1;
                          @(posedge vif.clk);  
                          end
 
                  else if(tr.op == writed)
                          begin
					      vif.rst <= 1'b0;
                          vif.wr  <= 1'b1;
                          vif.addr <= tr.addr;
                          vif.din  <= tr.din;
                          @(posedge vif.clk);
                          `uvm_info("DRV", $sformatf("mode : Write addr:%0d din:%0d", vif.addr, vif.din), UVM_MEDIUM);
                          wait_done();
                          end
                else if(tr.op ==  readd)
                          begin
					      vif.rst  <= 1'b0;
                          vif.wr   <= 1'b0;
                          vif.addr <= tr.addr;
                          vif.din  <= tr.din;
                          @(posedge vif.clk);
                            `uvm_info("DRV", $sformatf("mode : Read addr:%0d din:%0d", vif.addr, vif.din), UVM_MEDIUM);
                          wait_done();
                          end
       seq_item_port.item_done();
     
   end
  endtask
  
 
  virtual task run_phase(uvm_phase phase);
    drive();
  endtask
 
  
endclass