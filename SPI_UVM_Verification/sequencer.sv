 class spi_transaction extends uvm_sequence_item;
  
    rand oper_mode   op;
         logic       wr;
         logic       rst;
    randc logic [7:0] addr;
    rand logic [7:0] din;
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
        `uvm_field_enum(oper_mode, op, UVM_DEFAULT)
        `uvm_object_utils_end
  
  constraint addr_c { addr <= 10; }
  constraint addr_c_err { addr > 31; }
 
  function new(string name = "spi_transaction");
    super.new(name);
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
        tr.addr_c.constraint_mode(0);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        assert(tr.randomize);
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
        assert(tr.randomize);
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
        tr.addr_c.constraint_mode(0);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        assert(tr.randomize);
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
        assert(tr.randomize);
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
        assert(tr.randomize);
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
        tr.addr_c.constraint_mode(0);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        assert(tr.randomize);
        tr.op = writed;
        finish_item(tr);  
      end
        
    repeat(100)
      begin
        tr = spi_transaction::type_id::create("tr");
        tr.addr_c.constraint_mode(0);
        tr.addr_c_err.constraint_mode(0);
        start_item(tr);
        assert(tr.randomize);
        tr.op = readd;
        finish_item(tr);
      end   
    
  endtask
  
 
endclass