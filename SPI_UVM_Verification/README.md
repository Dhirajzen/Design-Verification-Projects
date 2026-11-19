# SPI Memory Link: UVM Verification Environment

A UVM environment for an SPI master and an SPI slave memory that support all
four SPI modes (CPOL/CPHA) and a programmable SCLK divider. The master
(`spi_intf`) takes a parallel read/write request and runs one 16-clock SPI
frame. The slave (`spi_mem`) holds a 32 x 8 memory. The environment checks
the result two ways: at the parallel side (readback against a reference
model) and at the SPI pins (a passive serial monitor decodes every frame and
the scoreboard checks it bit for bit). SVA bound into the master checks the
SPI timing rules.

**Result (seed 1):** 0 UVM errors. 658 SPI frames checked bit for bit, 404
readbacks compared, 40 rejected requests checked, 82 of 82 planned coverage
bins hit. Each of four injected RTL bugs makes the regression fail.

---

## 1. Design under test

```
     request side (clk domain)                        SPI pins
    +--------------------------+  CS (active low)  +----------------------------+
    | start  wr  addr  din     |------------------>| clock = SCLK, reset = CS    |
    | cpol cpha clk_div        |  SCLK             |                             |
--->|      spi_intf (master)   |------------------>|     spi_mem (slave)         |
<---| dout  done  err          |  MOSI             |     mem[0:31] x 8           |
    |                          |------------------>|                             |
    |                          |  MISO             |                             |
    |                          |<------------------|                             |
    +--------------------------+                   +----------------------------+
```

**Frame:** 16 SCLK cycles, MSB first, one CS-low window.

| Bits | MOSI (master to slave) | MISO (slave to master) |
|---|---|---|
| 15 | `wr` (1 write, 0 read) | 0 |
| 14:13 | 00 | 0 |
| 12:8 | `addr[4:0]` | 0 |
| 7:0 | write data (0 on a read) | read data (0 on a write) |

**Modes:**

| Mode | CPOL | CPHA | SCLK idle | Sample edge | Shift edge | First bit |
|---|---|---|---|---|---|---|
| 0 | 0 | 0 | low | rising (leading) | falling | valid when CS falls |
| 1 | 0 | 1 | low | falling (trailing) | rising | driven on first edge |
| 2 | 1 | 0 | high | falling (leading) | rising | valid when CS falls |
| 3 | 1 | 1 | high | rising (trailing) | falling | driven on first edge |

**Request rules:** pulse `start` for one cycle with `wr/addr/din/cpol/cpha/clk_div`
valid, and hold them until `done`. `clk_div` is the SCLK half period in clk
cycles, legal 4 to 15. The lower limit is the master's spec for its fastest
SCLK (clk / 8); the slave itself has no minimum because SCLK is its clock.
`addr > 31` or `clk_div < 4` is rejected: `err = 1`, `done = 1`, and CS
never falls.

**Master timing:** SCLK moves to the new CPOL idle level while CS is high. CS
falls one cycle later. Setup (CS fall to first edge) and hold (last edge to CS
rise) are each one half period.

**Slave:** like a real SPI device it has no system clock. SCLK is its clock
and CS is its asynchronous reset. It clocks off `sck = sclk ^ cpol ^ cpha`,
whose rising edge is the sample edge in every mode (MOSI shifts in, the bit
counter advances, a write commits) and whose falling edge is the shift edge
(the next MISO bit is driven). On a read, the shift edge after the 8th sample
drives data bit 7, in time for the master's next sample edge in either CPHA.
CPOL/CPHA only change while CS is high, so any `sck` edge they cause is held
off by the reset. Reset (system `rst`, which raises CS, or CS itself) clears
both FSMs but **not the memory**, so data written before reset must read back
after it.

## 2. Testbench architecture

```
 test ── spi_config (is_active) ──> config_db ──> agent
  └─ env
      ├─ agent
      │   ├─ uvm_sequencer
      │   ├─ driver          : request + mode on the pins, 1-cycle start, 2000-cycle watchdog on done
      │   ├─ mon             : request captured at start, response at done (parallel side)
      │   └─ spi_serial_mon  : passive, decodes each CS-low window from the SPI pins using CPOL/CPHA
      ├─ sco (scoreboard)
      │     write()     : reference memory, readback compare, err-flag check
      │     write_ser() : queues SPI frames; each request's frame is checked bit for bit
      └─ spi_coverage    : planned covergroup + plan-bin counters
 tb ── spi_i ── top (DUT)
                  └─ spi_checker bound into spi_intf (9 SVA properties + mode covers)
```

The serial monitor is created in active and passive mode, so the same agent
can be dropped into an SoC bench in passive mode and still check every frame
on the pins.

| File | Contents |
|---|---|
| `design.sv` | DUT: `spi_intf` (master), `spi_mem` (slave), `top`; `INJECT_*_BUG` defines |
| `interface.sv` | `spi_i`: request side and SPI pins |
| `checker.sv` | `spi_checker` SVA module and its `bind` into `spi_intf` |
| `sequencer.sv` | `spi_transaction` and all sequences |
| `driver.sv`, `monitor.sv`, `serial_monitor.sv`, `agent.sv`, `config.sv` | Agent |
| `scoreboard.sv`, `coverage.sv`, `env.sv`, `test.sv` | Checking, coverage, env, test |
| `tb_pkg.sv`, `testbench.sv` | Package and top module |
| `Makefile` | Build, run, pass/fail verdict, `make bug BUG=...` |

## 3. Verification plan

| ID | Feature | Stimulus | Check | Coverage |
|---|---|---|---|---|
| F1 | Write every legal address | `write_data`, `writeb_readb` | Reference updated; frame MOSI carries wr, addr, data | write x 32 addresses |
| F2 | Read back every legal address | `read_data`, `writeb_readb` | `dout` = reference; frame MISO byte = reference | read x 32 addresses |
| F3 | Illegal address, write and read | `write_err`, `read_err` | `err = 1`, no SPI frame | illegal x write/read |
| F4 | Illegal divider (`clk_div < 4`) | `cfg_err` | `err = 1`, no SPI frame | `err_div` |
| F5 | Data corner patterns | `write_corner_data` (00, FF, 55, AA, read back in the same mode) | Data and frame compare | din zero / ones / alt |
| F6 | Reset recovery | `reset_dut`, then `rd_after_rst` | Reads after reset match data written before | reset count |
| F7 | All four SPI modes | mode randomized per request | Frame decoded in the requested mode; SVA below | write x mode, read x mode (8) |
| F8 | SCLK speed | `clk_div` 4..15, corners weighted | Same checks at every speed | div = 4, div = 15 |
| F9 | SPI timing | all traffic | SVA: SCLK idle = CPOL when CS high; no SCLK edge with a CS edge; MOSI stable on sample edges; CPHA 0 first bit at CS fall; exactly 32 edges per frame; bounded CS window; mode stable during a frame | cover: a frame in each mode |
| F10 | Request/response | all traffic | SVA: err only with CS high and only for illegal requests; done only after CS rises | cover: error |
| F11 | No hangs, no vacuous pass | all traffic | Driver watchdog; `check_phase` fails on zero reads compared or unmatched frames | n/a |

**Coverage plan (82 bins):** 32 addresses written, 32 read, illegal address
on write and on read (2), `err` on write and on read (2), illegal divider (1),
data corners (3), write and read in each of the 4 modes (8), fastest and
slowest divider (2). Verilator parses covergroups but does not collect them,
so `spi_coverage` keeps counters for the same 82 bins and prints any bin it
missed. On a commercial simulator the covergroup percentage is printed too.

## 4. Results

Regression `test` (`make run`), seed 1:

```
SUMMARY writes:254 reads_matched:404 mismatches:0 err_expected_ok:40 err_flag_bad:0 resets:21 spi_frames_ok:658 spi_frames_bad:0
Plan bins hit: 82/82 (100.0%)
UVM_ERROR :    0
UVM_FATAL :    0
*** TEST test PASSED ***
```

Seeds 1 to 5: all pass with 0 errors and 82/82 bins.

### Does the environment catch bugs? (`make bug BUG=...`)

| Injected bug | Where | Caught by | UVM errors |
|---|---|---|---|
| `ADDR`: slave stores write data one address too high | slave data path | Readback compare (404) and MISO byte in the frame check (404). The MOSI side of every write frame is still correct, which localises the bug to the slave. | 808 |
| `MODE`: master idles SCLK low regardless of CPOL | master, CPOL | SVA `a_sclk_idle` and `a_mosi_stable_on_sample`. MOSI-side frame mismatches appear only in mode 2 frames; MISO and readback mismatches then spread to every mode, because those reads return data that was written wrong. | 2880 |
| `CPHA`: master samples on the leading edge whatever CPHA is | master, CPHA | SVA `a_mosi_stable_on_sample`. MOSI-side frame mismatches appear only in CPHA = 1 frames (modes 1 and 3), which points straight at the phase logic. | 1984 |
| `SLAVE_EDGE`: slave samples MOSI on the shift edge instead of the sample edge | slave, edge select | MISO byte in the frame check and the readback compare, in all four modes. MOSI at the pins is correct in every frame and no master SVA fires, which localises the bug to the slave. | 598 |

Every assertion added in `checker.sv` was also mutated once and confirmed to fire.

**The wrong-edge slave, before and after.** The first version of the slave
oversampled SCLK and MOSI through identical 2-flop synchronizers on the system
clock. A slave sampling on the wrong edge then *passed*: in zero-delay RTL
simulation it saw the new MOSI bit on the same edge it was launched and still
got the right data. With the slave clocked by SCLK, the same bug (`make bug
BUG=SLAVE_EDGE`) shifts the slave's view of the frame by one edge and fails
with 598 errors. What simulation still cannot see is a slave that samples on
the right edge but too close to it: setup and hold around SCLK edges need STA
or gate-level simulation with delays.

### History

The first version of this project had no SCLK and no modes, its scoreboard
reported mismatches with `uvm_info` (an injected bug gave 77 "TEST FAILED"
prints and still passed), most "good path" traffic went to illegal
addresses, and its monitor misclassified a read that followed a write. The
commit history on this branch walks through those fixes one at a time before
the SPI clocking and modes were added.

## 5. Known gaps and next steps

- **Mid-frame events.** Reset and CS abort in the middle of a frame are not
  stimulated (the slave does discard a partial frame when CS rises, but no
  test proves it).
- **Timing at the pins.** The simulation is zero-delay, so setup and hold of
  MOSI and MISO around SCLK edges (and the MISO round-trip delay back to the
  master, which samples it on `clk`) are not checked. That needs STA or
  gate-level simulation with delays. If the slave's memory were also read
  from a system bus, the SCLK-to-system crossing would need CDC checks.
- **Register interface.** Requests come from pins, not a bus. A real
  controller would have APB registers, FIFOs, an interrupt and a DMA request,
  plus a RAL model.
- **One regression test.** Splitting into a base test plus focused tests
  (per mode, per error type) and merging coverage across seeds is the next
  step for closure.
- The two original assertions in `interface.sv` (`done` is a one-cycle
  pulse, `err` implies `done`) still hold by construction.

## 6. How to run

Open-source flow (Verilator 5 with `--timing`, UVM port from
[antmicro/uvm-verilator](https://github.com/antmicro/uvm-verilator), and
`z3` on `PATH` for constraint solving, for example `pip install verilator z3-solver`;
the pip package names the binary `verilator-cli`, so add `VERILATOR=verilator-cli`):

```
make UVM_HOME=/path/to/uvm-verilator/src            # build and run, prints PASSED or FAILED
make run TEST=test SEED=3 UVM_HOME=...
make bug BUG=ADDR UVM_HOME=...                       # injected RTL bug, must FAIL (ADDR | MODE | CPHA | SLAVE_EDGE)
```

Commercial simulators use the same file list; the commands are at the top of
the `Makefile`.
