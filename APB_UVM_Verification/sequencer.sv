
class apb_packet extends uvm_sequence_item;

  `uvm_object_utils(apb_packet);

  randc bit psel;
  randc bit [7:0] paddr;
  rand bit [7:0] pwdata;
  randc bit penable;
  randc bit pwrite;
  bit [7:0] prdata; 
  bit pready;
  bit   pslverr;
  static int rand_count = 0;
 
  // constraint data { //paddr inside {[0:255]};
  //   pwdata dist{[0:31] :/13, [32:63] :/ 13,
  //               [64:95] :/13,[96:127] :/13,
  //               [128:159] :/13, [160:191] :/13,
  //               [192:223] :/13, [224:255] :/13};
  //              }
  // constraint write_count { if (rand_count <200) pwrite == 1;
  //                  else
  //                  	pwrite == 0;}


  function new (string name = "apb_packet");
    super.new(name);
  endfunction
  
  
  function void post_randomize();
    rand_count ++;
    $display("Itteration: %0d", rand_count);
  endfunction
                              

endclass: apb_packet

class apb_sequence extends uvm_sequence#(apb_packet);

  `uvm_object_utils(apb_sequence);
  
  apb_packet pkt; //added by me 
  int count = 0;

  function new (string name = "apb_sequence");
    super.new(name);
  endfunction

  task body;
    `uvm_info ("BASE_SEQ", $sformatf ("Generating sequence"), UVM_MEDIUM); 
    repeat(count) begin

      pkt = apb_packet::type_id::create("pkt");

      start_item(pkt); // added by me 
      assert(pkt.randomize()); // added by me 
      finish_item(pkt); // added by me 
	end
  endtask: body

endclass: apb_sequence


class apb_write_seq extends uvm_sequence#(apb_packet);

  `uvm_object_utils(apb_write_seq);
  
  apb_packet pkt; //added by me 
  int count = 0;

  function new (string name = "apb_write_seq");
    super.new(name);
  endfunction

  task body;
    `uvm_info ("WRITE_SEQ", $sformatf ("Generating write sequence"), UVM_MEDIUM); 
    repeat(count) begin

      pkt = apb_packet::type_id::create("pkt");

      start_item(pkt); // added by me 
      assert(pkt.randomize()); // added by me 
      pkt.pwrite = 1; // added by me to force write operation
      finish_item(pkt); // added by me 
  end
  endtask: body

endclass: apb_write_seq

class apb_read_seq extends uvm_sequence#(apb_packet);

  `uvm_object_utils(apb_read_seq);
  
  apb_packet pkt; //added by me 
  int count = 0;

  function new (string name = "apb_read_seq");
    super.new(name);
  endfunction

  task body;
    `uvm_info ("READ_SEQ", $sformatf ("Generating read sequence"), UVM_MEDIUM); 
    repeat(count) begin

      pkt = apb_packet::type_id::create("pkt");

      start_item(pkt); // added by me 
      assert(pkt.randomize()); // added by me 
      pkt.pwrite = 0; // added by me to force read operation
      finish_item(pkt); // added by me 
  end
  endtask: body

endclass: apb_read_seq

