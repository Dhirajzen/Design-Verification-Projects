# SPI Memory Link: UVM Verification Environment

A UVM environment for a small SPI-style link: a master (`spi_intf`) takes a
parallel read/write command and sends it serially to a slave (`spi_mem`) that
holds a 32 x 8 memory. The environment drives commands at the parallel side,
checks every readback against a reference model, checks the error response
for illegal addresses, and checks the chip-select protocol with SVA bound into
the master.

**Result:** the regression passes with 0 UVM errors, 404 readbacks compared,
30 error responses checked, and 71 of 71 planned coverage bins hit (seed 1).
An injected RTL bug fails the same regression with 404 mismatches.

---

## 1. Design under test

```
            parallel command side                 serial side (one system clock)
           +----------------------+   cs, mosi   +----------------------+
 wr  ----->|                      |------------->|                      |
 addr[7:0]>|   spi_intf (master)  |              |   spi_mem (slave)    |
 din[7:0]->|                      |<-------------|   mem[0:31] x 8 bit  |
 dout<-----|                      |  miso, ready,|                      |
 done,err<-|                      |  op_done     |                      |
           +----------------------+              +----------------------+
                         top (design.sv)
```

| Item | Behaviour in this RTL |
|---|---|
| Write frame | 17 bits, LSB first: `wr` (1), `addr[7:0]`, `din[7:0]`. Slave stores `din` at `addr` and pulses `op_done`. |
| Read frame | 9 bits out (`wr` = 0, `addr`), slave raises `ready`, then shifts 8 data bits back LSB first. |
| Legal addresses | 0 to 31. For `addr > 31` the master never lowers `cs` and returns `done` with `err = 1`. |
| Reset | Active-high, synchronous. Resets both FSMs. **Does not clear the memory**, so data written before reset must read back after it. |
| Clocking | One system clock for master and slave. There is no SCLK and no CPOL/CPHA mode: bits move one per system clock. |

## 2. Testbench architecture

```
 test ── spi_config (is_active) ──> config_db ──> agent
  └─ env
      ├─ agent
      │   ├─ uvm_sequencer
      │   ├─ driver   : drives wr/addr/din/rst, waits on done with a 1000-cycle watchdog
      │   └─ monitor  : one new item per completed transfer, op taken from wr when done rises
      ├─ sco (scoreboard) : 32 x 8 reference array, data compare, err-flag check, end-of-test summary
      └─ spi_coverage     : planned covergroup + plan-bin counters
 tb (top module) ── spi_i interface ── top (DUT)
                                         └─ spi_checker bound into spi_intf (SVA on cs/err/done)
```

| File | Contents |
|---|---|
| `design.sv` | DUT: `spi_intf`, `spi_mem`, `top` |
| `interface.sv` | `spi_i` interface on the parallel side |
| `checker.sv` | `spi_checker` SVA module and its `bind` into `spi_intf` |
| `sequencer.sv` | `spi_transaction` and all sequences |
| `driver.sv`, `monitor.sv`, `agent.sv`, `config.sv` | Agent |
| `scoreboard.sv`, `coverage.sv`, `env.sv`, `test.sv` | Checking, coverage, env, test |
| `tb_pkg.sv`, `testbench.sv` | Package and top module |
| `Makefile` | Build, run, pass/fail verdict, `make bug` |

## 3. Verification plan

| ID | Feature | Stimulus | Check | Coverage |
|---|---|---|---|---|
| F1 | Write to every legal address | `write_data`, `writeb_readb` (legal addresses only) | Reference array updated | `x_op_addr` write x 32 addresses |
| F2 | Read back every legal address | `read_data`, `writeb_readb` | `dout` equals reference, else `uvm_error` | `x_op_addr` read x 32 addresses |
| F3 | Illegal address on write | `write_err` (`addr > 31`) | `err = 1`, memory unchanged | `x_op_addr` write x illegal, `x_op_err` |
| F4 | Illegal address on read | `read_err` | `err = 1` | `x_op_addr` read x illegal, `x_op_err` |
| F5 | Data corner patterns | `write_corner_data` (00, FF, 55, AA, each read back) | Data compare | `cp_din` zero / ones / alt |
| F6 | Reset recovery | `reset_dut`, then `rd_after_rst` reads | Reads after reset match data written before it | scoreboard reset count |
| F7 | Chip-select protocol | all traffic | SVA: err only with cs high, err only for addr > 31, done only after cs released, cs window bounded | cover: write frame, read frame, ready, error |
| F8 | No hangs | all traffic | Driver watchdog `uvm_fatal` if `done` never comes | n/a |
| F9 | Nothing passes vacuously | all traffic | `check_phase` fails the test if zero reads were compared | n/a |

**Coverage plan (71 bins):** 32 addresses written, 32 addresses read, the
illegal range written and read (2), `err` on a write and on a read (2), and
data corners 00, FF, 55/AA (3). Verilator parses covergroups but does not
collect them, so `spi_coverage` also keeps plain counters for the same 71
bins and prints the bins it missed. On a commercial simulator the covergroup
percentage is printed as well.

## 4. Results

Regression `test` (`make run`), seed 1:

```
SUMMARY writes:254 reads_matched:404 mismatches:0 err_expected_ok:30 err_flag_bad:0 resets:5
Plan bins hit: 71/71 (100.0%)
UVM_ERROR :    0
UVM_FATAL :    0
*** TEST test PASSED ***
```

Seed sweep 1 to 5: all pass with 0 errors. Seeds 1, 2, 4 and 5 reach 71/71;
seed 3 reaches 70/71 (no write to address 31). Coverage closure is therefore
measured over the merged seeds, not trusted from a single run.

### Before and after (same RTL, same simulator)

| | Original environment | This environment |
|---|---|---|
| Good-path items that hit a legal address | about 13% (both address constraints off) | 100% |
| Readbacks actually compared | 77 | 404 |
| Verdict on a wrong readback | `uvm_info`, test still passes | `uvm_error`, test fails |
| Injected RTL bug (`make bug`) | 77 "TEST FAILED" prints, **UVM_ERROR 0, passes** | **404 mismatches, fails** |
| DUT never returns `done` | hangs until the farm kills it | `uvm_fatal` after 1000 cycles |
| Assertions | 2, neither can fail on this RTL | 4 bound checks, each shown to fire when mutated |
| Coverage | 128 auto bins, reset items sampled | 71 planned bins, reset items excluded |

### Bugs found

1. **Testbench, monitor misclassification.** Found as soon as the scoreboard
   could fail. The monitor decided write or read at the start of a transfer,
   when `wr` could still hold the previous item's value. A read that followed
   a write was reported as a write, so the reference model was overwritten
   with the read's `din` and later readbacks of that address mismatched
   (3 errors in the first run). Fixed by taking the operation from `wr` when
   `done` rises.
2. **Testbench, checker could not fail.** Mismatches were printed with
   `uvm_info`, so the regression stayed green with a broken read path.

### RTL review findings (reported, not changed in the DUT)

- `spi_mem` reads `mem[datain]` with the full 16-bit `datain`; it works only
  because `datain` is cleared in `idle`. It should be `mem[datain[7:0]]`.
- Both FSMs mix blocking (`state = send_data`) and non-blocking assignments
  to `state` in the same clocked block.
- There is no start or valid input: from `idle` the master goes straight to
  `load` and re-executes whatever is on `wr/addr/din`. The environment relies
  on the driver changing the pins in the same cycle `done` rises.
- Port names are swapped at the slave: the master's `mosi` drives the
  slave's port called `miso`, and the other way round.
- `dout_reg` is not reset.

## 5. Known gaps and next steps

- **No real SPI clock.** SCLK generation and the four CPOL/CPHA modes are
  not in this DUT. Next step is a master with a clock divider and
  configurable CPOL/CPHA, a serial-side passive monitor on CS/SCLK/MOSI/MISO,
  and coverage of mode x transfer type.
- No register model (RAL) and no interrupt path; the command interface is
  parallel pins rather than a bus.
- One regression test class. Splitting it into a base test plus focused
  tests, and running seed sweeps with merged coverage, is the next step for
  closure.
- The two original assertions in `interface.sv` (`done` is a one-cycle pulse,
  `err` implies `done`) hold by construction in this RTL; the bound checker
  covers the properties that can actually fail.

## 6. How to run

Open-source flow (Verilator 5 with `--timing`, UVM port from
[antmicro/uvm-verilator](https://github.com/antmicro/uvm-verilator), and
`z3` on `PATH` for constraint solving, for example `pip install verilator z3-solver`;
the pip package names the binary `verilator-cli`, so add `VERILATOR=verilator-cli`):

```
make UVM_HOME=/path/to/uvm-verilator/src            # build and run, prints PASSED or FAILED
make run TEST=test SEED=3 UVM_HOME=...
make bug UVM_HOME=...                                # injected RTL bug, must FAIL
```

Commercial simulators use the same file list; the commands are at the top of
the `Makefile`.
