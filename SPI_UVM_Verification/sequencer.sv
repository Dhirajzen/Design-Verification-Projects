 class spi_transaction extends uvm_sequence_item;
  
    rand oper_mode   op;
         logic       wr;
         logic       rst;
    randc logic [7:0] addr;
    rand logic [7:0] din;
    rand bit         cpol, cpha;   // SPI mode for this transfer
    rand bit   [3:0] clk_div;      // SCLK half period in clk cycles (legal 4..15)
         logic [7:0] dout; 
         logic done;
         logic err;
  
 
        `uvm_object_utils_begin(spi_transaction)
        `uvm_field_int (wr,UVM_ALL_ON)
        `uvm_field_int (rst,UVM_ALL_ON)
        `uvm_field_int (addr,UVM_ALL_ON)
        `uvm_field_int (din,UVM_ALL_ON)
        `uvm_field_int (dout,UVM_ALL_ON)
        `uvm_field_int (done,UVM_ALL_ON)
        `uvm_field_int (err,UVM_ALL_ON)
        `uvm_field_int (cpol,UVM_ALL_ON)
        `uvm_field_int (cpha,UVM_ALL_ON)
        `uvm_field_int (clk_div,UVM_ALL_ON)
        `uvm_field_enum(oper_mode, op, UVM_DEFAULT)
        `uvm_object_utils_end
  
  // Legal address map is 0..31 (32 x 8 memory). The two constraints are mutually
  // exclusive: good-path sequences enable addr_c, error sequences enable addr_c_err.
  constraint addr_c     { addr inside {[0:31]}; }
  constraint addr_c_err { addr > 31; }

  // Divider: legal range only, with extra weight on the two corners.
  // div_c_err (off by default) selects the illegal values 0..3 instead.
  constraint div_c      { clk_div dist {4 := 3, [5:14] :/ 4, 15 := 3}; }
  constraint div_c_err  { clk_div < 4; }
 
  function new(string name = "spi_transaction");
    super.new(name);
    div_c_err.constraint_mode(0);
  endfunction
 
endclass : spi_transaction
 
 
///////////////////////////////////////////////////////////////////////
 
 
///////////////////write seq
class write_data extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(write_data)
  
  spi_transaction tr;
 
  function new(string name = "write_data");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(150)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   // legal addresses only
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = writed;
        finish_item(tr);
      end
  endtask
  
 
endclass
//////////////////////////////////////////////////////////
 
 
class write_err extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(write_err)
  
  spi_transaction tr;
 
  function new(string name = "write_err");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(15)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c_err.constraint_mode(1);
        tr.addr_c.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = writed;
        finish_item(tr);
      end
  endtask
  
 
endclass
 
///////////////////////////////////////////////////////////////
 
class read_data extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(read_data)
  
  spi_transaction tr;
 
  function new(string name = "read_data");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(150)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   // legal addresses only
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = readd;
        finish_item(tr);
      end
  endtask
  
 
endclass
/////////////////////////////////////////////////////////////////////
 
class read_err extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(read_err)
  
  spi_transaction tr;
 
  function new(string name = "read_err");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(15)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(0);
        tr.addr_c_err.constraint_mode(1);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = readd;
        finish_item(tr);
      end
  endtask
  
 
endclass
/////////////////////////////////////////////////////////////////
 
class reset_dut extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(reset_dut)
  
  spi_transaction tr;
 
  function new(string name = "reset_dut");
    super.new(name);
  endfunction
  
  virtual task body();
    repeat(15)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = rstdut;
        finish_item(tr);
      end
  endtask
  
 
endclass
////////////////////////////////////////////////////////////
 
 
 
class writeb_readb extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(writeb_readb)
  
  spi_transaction tr;
 
  function new(string name = "writeb_readb");
    super.new(name);
  endfunction
  
  virtual task body();
     
    repeat(100)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   // legal addresses only
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = writed;
        finish_item(tr);  
      end
        
    repeat(100)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);   // legal addresses only
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")  // not assert(): $assertoff would skip the call
        tr.op = readd;
        finish_item(tr);
      end   
    
  endtask
  
 
endclass
////////////////////////////////////////////////////////////
// Coverage closure: random 8-bit data rarely hits 0x00 / 0xFF in a few hundred
// writes (the first regression missed both bins). Directed corner patterns are
// written to random legal addresses and read straight back.
class write_corner_data extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(write_corner_data)

  spi_transaction tr;
  bit [7:0] patterns[4] = '{8'h00, 8'hFF, 8'h55, 8'hAA};

  function new(string name = "write_corner_data");
    super.new(name);
  endfunction

  virtual task body();
    bit [7:0] a;
    spi_transaction w;
    foreach (patterns[i])
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        if (!tr.randomize() with { din == patterns[i]; }) `uvm_fatal("SEQ", "randomize() failed")
        tr.op = writed;
        a = tr.addr;
        w = tr;
        finish_item(tr);

        tr = spi_transaction::type_id::create("tr");   // read the same address back
        start_item(tr);
        tr.op      = readd;
        tr.addr    = a;
        tr.cpol    = w.cpol;      // read back in the same mode and speed
        tr.cpha    = w.cpha;
        tr.clk_div = w.clk_div;
        finish_item(tr);
      end
  endtask
endclass

////////////////////////////////////////////////////////////
// Illegal divider (clk_div < 4) with a legal address: must be rejected with
// err = 1 and no SPI frame, on both writes and reads.
class cfg_err extends uvm_sequence#(spi_transaction);
  `uvm_object_utils(cfg_err)

  spi_transaction tr;

  function new(string name = "cfg_err");
    super.new(name);
  endfunction

  virtual task body();
    repeat(10)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(1);
        tr.addr_c_err.constraint_mode(0);
        tr.div_c.constraint_mode(0);
        tr.div_c_err.constraint_mode(1);
        start_item(tr);
        if (!tr.randomize()) `uvm_fatal("SEQ", "randomize() failed")
        tr.op = $urandom_range(0,1) ? writed : readd;
        finish_item(tr);
      end
  endtask
endclass
