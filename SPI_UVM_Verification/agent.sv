// The uvm sequence, spi_transaction item, and driver are in these files:

class agent extends uvm_agent;
`uvm_component_utils(agent)
  
  spi_config cfg;
 
function new(input string inst = "agent", uvm_component parent = null);
  super.new(inst,parent);
endfunction
 
 driver d;
 uvm_sequencer#(spi_transaction) seqr;
 mon m;
 
 
virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    // Take the configuration from the test so the agent can be made passive
    // (monitor only) when this env is reused at subsystem/SoC level.
    if(!uvm_config_db#(spi_config)::get(this, "", "cfg", cfg))
      cfg = spi_config::type_id::create("cfg");   // default: active
    `uvm_info("AGT", $sformatf("agent is %s", cfg.is_active.name()), UVM_LOW)
    m = mon::type_id::create("m",this);

    if(cfg.is_active == UVM_ACTIVE)
    begin   
    d = driver::type_id::create("d",this);
    seqr = uvm_sequencer#(spi_transaction)::type_id::create("seqr", this);
    end
  
  
endfunction
 
virtual function void connect_phase(uvm_phase phase);
  super.connect_phase(phase);
    if(cfg.is_active == UVM_ACTIVE) begin  
      d.seq_item_port.connect(seqr.seq_item_export);
    end

endfunction
 
endclass