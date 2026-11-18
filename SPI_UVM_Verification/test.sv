



class test extends uvm_test;
  `uvm_component_utils(test)
  
  function new(input string inst = "test", uvm_component c);
    super.new(inst,c);
  endfunction
  
  env e;

  write_data wdata;
  write_err werr;
  read_data rdata;
  read_err rerr;
  writeb_readb wrrdb;
  reset_dut rstdut;  
  write_corner_data wcorner;  // coverage closure: data corner patterns
  read_data rd_after_rst;   // readback after reset: memory contents must survive reset
  spi_config cfg;
  
    
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
      cfg    = spi_config::type_id::create("cfg");
      cfg.is_active = UVM_ACTIVE;
      uvm_config_db#(spi_config)::set(this, "env.a", "cfg", cfg);
      e      = env::type_id::create("env",this);
      wdata  = write_data::type_id::create("wdata");
      werr   = write_err::type_id::create("werr");
      rdata  = read_data::type_id::create("rdata");
      wrrdb  = writeb_readb::type_id::create("wrrdb");
      rerr   = read_err::type_id::create("rerr");
      rstdut = reset_dut::type_id::create("rstdut");
      wcorner = write_corner_data::type_id::create("wcorner");
      rd_after_rst = read_data::type_id::create("rd_after_rst");
  endfunction
  
  virtual task run_phase(uvm_phase phase);
    phase.raise_objection(this);
      wrrdb.start(e.a.seqr);
      #20;
      wdata.start(e.a.seqr);
      #20;
      wcorner.start(e.a.seqr);
      #20;
      werr.start(e.a.seqr);
      #20;
      rdata.start(e.a.seqr);
      #20;
      rerr.start(e.a.seqr);
      #20;
      rstdut.start(e.a.seqr);
      #20;
      // Reset recovery: the slave memory is not cleared by reset, so every
      // read after reset must still return the last data written before it.
      rd_after_rst.start(e.a.seqr);
      #20;
    phase.drop_objection(this);
  endtask
endclass