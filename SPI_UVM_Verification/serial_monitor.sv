// Passive monitor on the SPI pins (CS, SCLK, MOSI, MISO).
//
// It knows nothing about the parallel side. It decodes each CS-low window
// using the SPI mode on the cpol/cpha pins (in an SoC these would come from the
// controller's configuration register), sampling MOSI and MISO on the
// mode's sample edge exactly as a real SPI device would.

class spi_serial_item extends uvm_sequence_item;
  `uvm_object_utils(spi_serial_item)

  bit        cpol, cpha;
  int        nbits;        // sample edges seen while CS was low (16 for a full frame)
  bit [15:0] mosi_bits;    // MSB first
  bit [15:0] miso_bits;

  // decoded fields (valid when nbits == 16)
  function bit       wr();    return mosi_bits[15];      endfunction
  function bit [4:0] addr();  return mosi_bits[12:8];    endfunction
  function bit [7:0] wdata(); return mosi_bits[7:0];     endfunction
  function bit [7:0] rdata(); return miso_bits[7:0];     endfunction

  function new(string name = "spi_serial_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("mode:%0d bits:%0d wr:%0d addr:%0d mosi_data:%0d miso_data:%0d",
                     {cpol, cpha}, nbits, wr(), addr(), wdata(), rdata());
  endfunction
endclass


class spi_serial_mon extends uvm_monitor;
  `uvm_component_utils(spi_serial_mon)

  uvm_analysis_port#(spi_serial_item) send;
  virtual spi_i vif;

  function new(string name = "spi_serial_mon", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    send = new("send", this);
    if (!uvm_config_db#(virtual spi_i)::get(this, "", "vif", vif))
      `uvm_fatal("SMON", "Unable to access Interface")
  endfunction

  virtual task run_phase(uvm_phase phase);
    spi_serial_item it;
    bit lead;
    forever begin
      @(negedge vif.cs);
      if (vif.rst) continue;
      it = spi_serial_item::type_id::create("it");
      it.cpol = vif.cpol;
      it.cpha = vif.cpha;

      // CPOL/CPHA rules: leading edge = SCLK leaving its idle level.
      // CPHA 0 samples on the leading edge, CPHA 1 on the trailing edge.
      forever begin
        @(vif.sclk or posedge vif.cs);
        if (vif.cs) break;                       // end of frame (or abort)
        lead = (vif.sclk != it.cpol);
        if (lead != it.cpha) begin               // this is a sample edge
          it.mosi_bits = {it.mosi_bits[14:0], vif.mosi};
          it.miso_bits = {it.miso_bits[14:0], vif.miso};
          it.nbits++;
        end
      end

      `uvm_info("SMON", it.convert2string(), UVM_MEDIUM)
      send.write(it);
    end
  endtask
endclass
