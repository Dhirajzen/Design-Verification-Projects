

`include "env.sv"

class apb_test extends uvm_test;
  
  //use the correct uvm utils macro to register this object
  `uvm_component_utils (apb_test); //added by me

  //add an instance of the environment object to your test (recall that uvm_test encapsulates uvm_env)
  apb_env env; //added by me
  

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    //initialize the environment object using type_id::create("env", this) syntax
    env = apb_env::type_id::create("env", this); //added by me
    `uvm_info("TEST", $sformatf("TEST test build Passed"), UVM_MEDIUM);
    uvm_top.print_topology();
  endfunction

  task run_phase(uvm_phase phase);
<<<<<<< HEAD
    env.agent.seq.count = 312;
=======
    env.agent.seq.count = 200;
    env.agent.write_seq.count = 200;
    env.agent.read_seq.count = 200;
>>>>>>> 49717f7 (Enhance APB agent and sequences: add write/read sequences, adjust counts, and clean up code)
     // the test run_phase is empty. The env and agent run_phase take care of things.
  endtask


endclass
