// The uvm sequence, transaction item, and driver are in these files:
`include "sequencer.sv"
`include "monitor.sv"
`include "driver.sv"
`include "coverage.sv"

// The agent contains sequencer, driver, and monitor
class apb_agent extends uvm_agent;
   
   //register agent using uvm_macros
  `uvm_component_utils(apb_agent);

  //declare the monitor and driver objects
  apb_driver drv;  
  apb_monitor mon;  
  apb_sequence seq;  
  apb_write_seq write_seq;
  apb_read_seq read_seq;
  apb_coverage cov;

  
  
  // our sequencer initialized
  uvm_sequencer#(apb_packet) sequencer;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    // driver, sequencer, and monitor objects initialized
	//initialize driver, sequencer, and monitor objects
    drv = apb_driver::type_id::create("drv", this); 
    mon = apb_monitor::type_id::create("mon", this); 
    seq = apb_sequence::type_id::create("seq", this); 
    write_seq = apb_write_seq::type_id::create("write_seq", this); 
    read_seq = apb_read_seq::type_id::create("read_seq", this);
    cov = apb_coverage::type_id::create("cov", this); 
    sequencer = uvm_sequencer#(apb_packet)::type_id::create("sequencer", this); 
    `uvm_info("TEST", $sformatf("Agent build Passed"), UVM_MEDIUM); 
  endfunction    

  // connect_phase of the agent
  function void connect_phase(uvm_phase phase);
	//connect the driver and the sequencer
    drv.seq_item_port.connect(sequencer.seq_item_export);

    mon.mon_analysis_port.connect(cov.apb_cover_imp); 

    `uvm_info("TEST", $sformatf("Agent connect Passed"), UVM_MEDIUM); 
  endfunction

  task run_phase(uvm_phase phase);
    // We raise objection to keep the test from completing
    phase.raise_objection(this);
    `uvm_info("TEST", $sformatf("Agent run Started"), UVM_MEDIUM); 
	  //create sequence and start it.
    write_seq.start(sequencer);
    read_seq.start(sequencer);
    // We drop objection to allow the test to complete
    phase.drop_objection(this);
  endtask


endclass
