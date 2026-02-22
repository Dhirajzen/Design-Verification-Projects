class spi_coverage extends uvm_subscriber;
  
  `uvm_component_utils(spi_coverage)

  uvm_analysis_imp#(spi_transaction, spi_coverage) cov_imp;
  spi_transaction tr;

  
  function new(string name, uvm_component parent);
    super.new(name, parent);
   check = new();
  endfunction
  

    covergroup check;
        option.per_instance = 1;
        option.auto_bin_max = 8;

        coverpoint tr.wr {
            bins wr_0 = {0};
            bins wr_1 = {1};
        }
        coverpoint tr.addr {
            option.at_least = 8;
        }
        coverpoint tr.din {
            option.at_least = 8;
        }

        coverpoint tr.err;

        cross tr.wr, tr.addr, tr.din;
    endgroup
  

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cov_imp = new("cov_imp", this);
     
    `uvm_info("TEST", $sformatf("COVER build Passed"), UVM_MEDIUM);
  endfunction
  


    virtual function void write(spi_transaction t);
        tr = t;
        check.sample();
    endfunction
  
endclass