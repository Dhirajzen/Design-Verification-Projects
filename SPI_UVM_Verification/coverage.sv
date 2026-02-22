class spi_coverage extends uvm_subscriber;
  
  `uvm_component_utils(spi_coverage)

  uvm_analysis_imp#(spi_transaction, spi_coverage) cov_imp;
  spi_transaction tr;

  
  function new(string name, uvm_component parent);
    super.new(name, parent);
   
  endfunction
  

    covergroup check;
        option.per_instance = 1;
        option.auto_bin_max = 8;

        coverpoint vif.wr {
            bins wr_0 = {0};
            bins wr_1 = {1};
        }
        coverpoint vif.addr {
            option.at_least = 8;
        }
        coverpoint vif.din {
            option.at_least = 8;
        }

        coverpoint vif.err;

        cross vif.wr, vif.addr, vif.din;
    endgroup
  

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cov_imp = new("cov_imp", this);
     check = new();
    `uvm_info("TEST", $sformatf("COVER build Passed"), UVM_MEDIUM);
  endfunction
  


    virtual function void write(spi_transaction t);
        tr = t;
        check.sample();
    endfunction
  
endclass