// SPI master + SPI slave memory, all four SPI modes (CPOL/CPHA).
//
// Frame (16 SCLK cycles, MSB first, one CS-low window):
//   MOSI: [15] wr  [14:13] 2'b00  [12:8] addr[4:0]  [7:0] write data (0 on reads)
//   MISO: [15:8] don't care (0)                     [7:0] read data  (0 on writes)
//
// Mode rules (standard SPI):
//   CPOL = idle level of SCLK.  Leading edge = first edge out of idle.
//   CPHA = 0: sample on the leading edge, shift on the trailing edge,
//             first bit must be valid when CS falls.
//   CPHA = 1: shift on the leading edge, sample on the trailing edge.
//
// Requests: pulse start for one cycle with wr/addr/din/cpol/cpha/clk_div valid,
// and hold them until done. addr > 31 or clk_div < 4 is rejected with err = 1
// and CS never falls.


//////////////////////////////////////////////////////////////////////////////
// SPI master
//////////////////////////////////////////////////////////////////////////////
module spi_intf (
  input  logic       clk, rst,
  input  logic       start,          // 1-cycle request, accepted only in IDLE
  input  logic       wr,
  input  logic [7:0] addr, din,
  input  logic       cpol, cpha,     // SPI mode
  input  logic [3:0] clk_div,        // SCLK half period in clk cycles, legal 4..15
  output logic [7:0] dout,
  output logic       done, err,
  output logic       cs,             // chip select, active low
  output logic       sclk, mosi,
  input  logic       miso
);

  typedef enum logic [2:0] {IDLE, LOAD, SETUP, XFER, HOLD, FINISH, ERROR} state_t;
  state_t state;

  logic        wr_q, cpol_q, cpha_q;
  logic [3:0]  div_q;
  logic [15:0] tx_q, rx_q;
  logic [3:0]  timer;
  logic [5:0]  edge_cnt;            // 32 SCLK edges per frame: even = leading, odd = trailing

  wire lead_edge   = (edge_cnt[0] == 1'b0);
`ifdef INJECT_CPHA_BUG
  wire sample_edge = lead_edge;                  // deliberate bug: master ignores CPHA
`else
  wire sample_edge = cpha_q ? !lead_edge : lead_edge;
`endif

  always_ff @(posedge clk) begin
    if (rst) begin
      state    <= IDLE;
      cs       <= 1'b1;
      sclk     <= 1'b0;
      mosi     <= 1'b0;
      done     <= 1'b0;
      err      <= 1'b0;
      dout     <= 8'h00;
      cpol_q   <= 1'b0;
      cpha_q   <= 1'b0;
      div_q    <= 4'd4;
      wr_q     <= 1'b0;
      tx_q     <= '0;
      rx_q     <= '0;
      timer    <= '0;
      edge_cnt <= '0;
    end
    else begin
      case (state)
        IDLE: begin
          cs     <= 1'b1;
          done   <= 1'b0;
          err    <= 1'b0;
          mosi   <= 1'b0;
          // SCLK follows the programmed idle level while CS is high
          cpol_q <= cpol;
          cpha_q <= cpha;
`ifdef INJECT_MODE_BUG
          sclk   <= 1'b0;               // deliberate bug: idle level ignores CPOL
`else
          sclk   <= cpol;
`endif
          if (start) begin
            if (addr > 8'd31 || clk_div < 4'd4)
              state <= ERROR;
            else begin
              wr_q  <= wr;
              div_q <= clk_div;
              tx_q  <= {wr, 2'b00, addr[4:0], (wr ? din : 8'h00)};
              state <= LOAD;
            end
          end
        end

        // SCLK is already at its idle level; drop CS one cycle later so a
        // slave never sees an SCLK change and a CS fall in the same cycle.
        LOAD: begin
          cs       <= 1'b0;
          timer    <= '0;
          edge_cnt <= '0;
          rx_q     <= '0;
          if (!cpha_q) begin            // CPHA = 0: first bit valid at CS fall
            mosi <= tx_q[15];
            tx_q <= {tx_q[14:0], 1'b0};
          end
          state <= SETUP;
        end

        // CS-to-first-edge setup time: one half period
        SETUP: begin
          if (timer == div_q - 1) begin
            timer <= '0;
            state <= XFER;
          end
          else
            timer <= timer + 1;
        end

        XFER: begin
          if (timer == div_q - 1) begin
            timer    <= '0;
            sclk     <= ~sclk;
            edge_cnt <= edge_cnt + 1;
            if (sample_edge)
              rx_q <= {rx_q[14:0], miso};
            else if (!(edge_cnt == 6'd31)) begin   // shift edge (none after the last edge)
              mosi <= tx_q[15];
              tx_q <= {tx_q[14:0], 1'b0};
            end
            if (edge_cnt == 6'd31)
              state <= HOLD;
          end
          else
            timer <= timer + 1;
        end

        // Last-edge-to-CS-rise hold time: one half period
        HOLD: begin
          if (timer == div_q - 1) begin
            timer <= '0;
            cs    <= 1'b1;
            state <= FINISH;
          end
          else
            timer <= timer + 1;
        end

        FINISH: begin
          done  <= 1'b1;
          if (!wr_q)
            dout <= rx_q[7:0];
          state <= IDLE;
        end

        ERROR: begin
          err   <= 1'b1;
          done  <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule


//////////////////////////////////////////////////////////////////////////////
// SPI slave with a 32 x 8 memory
//
// The slave runs on the system clock and oversamples SCLK, CS and MOSI through
// 2-flop synchronizers (in a real system they come from off chip and are
// asynchronous to clk). Synchronizer latency is 2-3 cycles, which is why the
// master's SCLK half period must be at least 4 clk cycles.
//////////////////////////////////////////////////////////////////////////////
module spi_mem (
  input  logic clk, rst,
  input  logic cpol, cpha,          // mode straps
  input  logic cs, sclk, mosi,
  output logic miso
);

  logic [7:0] mem [0:31] = '{default: 8'h00};   // not cleared by reset

  logic [2:0] sclk_s, cs_s;
  logic [1:0] mosi_s;
  always_ff @(posedge clk) begin
    sclk_s <= {sclk_s[1:0], sclk};
    cs_s   <= {cs_s[1:0],   cs};
    mosi_s <= {mosi_s[0],   mosi};
  end

  wire cs_low    = !cs_s[1];
  wire cs_fall   =  cs_s[2] && !cs_s[1];
  wire sclk_edge =  sclk_s[2] != sclk_s[1];
  wire lead      =  sclk_edge && (sclk_s[1] != cpol);
  wire trail     =  sclk_edge && (sclk_s[1] == cpol);
  wire sample    =  cpha ? trail : lead;
  wire shift     =  cpha ? lead  : trail;
  wire mosi_bit  =  mosi_s[1];                   // aligned with sclk_s[1]

  logic [7:0] rx, tx, cmd;
  logic [4:0] cnt;                               // bits sampled in this frame

  always_ff @(posedge clk) begin
    if (rst) begin
      cnt  <= '0;
      rx   <= '0;
      tx   <= '0;
      cmd  <= '0;
      miso <= 1'b0;
    end
    else if (!cs_low || cs_fall) begin           // CS high (idle or aborted frame), or new frame
      cnt  <= '0;
      tx   <= '0;
      miso <= 1'b0;
    end
    else begin
      if (sample) begin
        rx  <= {rx[6:0], mosi_bit};
        cnt <= cnt + 1;
        if (cnt == 5'd7) begin                   // command byte complete
          cmd <= {rx[6:0], mosi_bit};
          if (!rx[6])                            // read: load data for the second byte
            tx <= mem[{rx[3:0], mosi_bit}];
        end
        if (cnt == 5'd15 && cmd[7])              // write: data byte complete
`ifdef INJECT_ADDR_BUG
          mem[cmd[4:0] + 5'd1] <= {rx[6:0], mosi_bit};   // deliberate bug for checker validation
`else
          mem[cmd[4:0]] <= {rx[6:0], mosi_bit};
`endif
      end
      if (shift) begin
        miso <= tx[7];
        tx   <= {tx[6:0], 1'b0};
      end
    end
  end
endmodule


//////////////////////////////////////////////////////////////////////////////
module top (
  input  logic       clk, rst, start, wr, cpol, cpha,
  input  logic [3:0] clk_div,
  input  logic [7:0] addr, din,
  output logic [7:0] dout,
  output logic       done, err,
  output logic       cs, sclk, mosi, miso      // SPI pins, brought out for the serial monitor
);
  spi_intf intf     (.clk, .rst, .start, .wr, .addr, .din, .cpol, .cpha, .clk_div,
                     .dout, .done, .err, .cs, .sclk, .mosi, .miso);
  spi_mem  mem_inst (.clk, .rst, .cpol, .cpha, .cs, .sclk, .mosi, .miso);
endmodule
