# Baseline Architecture

## Purpose

The baseline controller provides the conventional FPGA I2C-master
implementation used for all later functional, verification, timing,
and FPGA PPA comparisons.

The baseline is intentionally kept free of the proposed fault-management
extensions.

Its purpose is to provide a fair matched reference for evaluating the
incremental cost and behavior of the fault-aware controller.

The baseline and proposed controllers must share the same core I2C
protocol engine wherever possible.

The proposed controller will later add only the hardware required for:

- F1 SDA-stuck-LOW detection and recovery;
- F2 prolonged-SCL-LOW detection and containment;
- fault classification;
- recovery status;
- fault-related latency measurement.

The baseline does not contain these fault-management mechanisms.

---

## Frozen Functional Scope

The initial baseline target is:

- FPGA family: Xilinx Artix-7;
- FPGA part: XC7A35T-1CPG236C;
- reference board: Basys 3;
- Vivado version: 2024.1;
- RTL language: SystemVerilog;
- system clock target: 100 MHz;
- I2C operating mode: Standard-mode;
- nominal I2C SCL frequency: 100 kHz;
- addressing: 7-bit;
- topology: single-controller;
- transaction data width: 8 bits;
- single-byte write support;
- single-byte read support;
- START generation;
- STOP generation;
- ACK detection;
- NACK handling;
- controller-generated NACK after the final read byte;
- open-drain SDA behavior;
- open-drain SCL behavior;
- legal clock-stretch observation;
- bus-free timing support.

Repeated START may remain architecturally possible, but it is not a
mandatory blocker for the primary 15-day F1/F2 experiment.

The initial scope does not require:

- 10-bit addressing;
- Fast-mode;
- Fast-mode Plus;
- High-speed mode;
- multi-controller implementation;
- arbitration logic as a primary research feature;
- UVM;
- fault recovery;
- timeout detection;
- SDA bus-clear logic;
- F1/F2 fault classification.

---

## Architectural Partition

The baseline controller is divided conceptually into four main blocks.

```text
Host Command Interface
        |
        v
Transaction FSM
        |
        v
Bit / Timing Engine
        |
        v
Open-Drain Bus Interface
        |
        v
      SDA / SCL
```

### Host Command Interface

Accepts a read or write command from the testbench or future FPGA
wrapper.

### Transaction FSM

Controls byte-level I2C protocol sequencing including:

- START;
- address transmission;
- R/W direction;
- acknowledgement handling;
- write-data transmission;
- read-data reception;
- controller NACK after the final read byte;
- STOP;
- transaction completion.

### Bit / Timing Engine

Controls lower-level I2C bit timing including:

- SCL LOW timing;
- SDA setup;
- SCL release;
- observation of actual SCL;
- legal clock stretching;
- SCL HIGH timing;
- SDA sampling;
- return to SCL LOW.

### Open-Drain Bus Interface

Separates the controller's intention to pull a line LOW from the
actual externally observed bus state.

This is required for correct I2C operation and later controlled fault
injection.

---

## Host Command Interface

The baseline controller core will use the following initial interface.

```systemverilog
input  logic       clk;
input  logic       rst_n;

input  logic       cmd_valid;
output logic       cmd_ready;

input  logic       cmd_rw;
input  logic [6:0] cmd_addr;
input  logic [7:0] cmd_wdata;

output logic [7:0] read_data;
output logic       busy;
output logic       done;
output logic       nack;

input  logic       sda_in;
input  logic       scl_in;

output logic       sda_drive_low;
output logic       scl_drive_low;
```

Command direction:

```text
cmd_rw = 0 -> WRITE
cmd_rw = 1 -> READ
```

### Command Acceptance

A new command is accepted only when:

- the controller is idle;
- `cmd_ready` is asserted;
- `cmd_valid` is asserted;
- the bus-start requirements are satisfied.

### Transaction Status

`busy` is asserted while a transaction is active.

`done` is asserted when the requested transaction completes.

`nack` indicates that a target-generated NACK was observed during the
relevant address or write-data acknowledgement phase.

---

## Transaction FSM

The transaction FSM controls byte-level protocol sequencing.

A representative state set may include:

```text
IDLE
START
SEND_ADDRESS
ADDRESS_ACK
WRITE_DATA
WRITE_ACK
READ_DATA
MASTER_NACK
STOP
DONE
```

The exact RTL state encoding will be selected during implementation.

### Write Transaction

Representative one-byte write sequence:

```text
IDLE
  |
  v
START
  |
  v
SEND ADDRESS + WRITE
  |
  v
ADDRESS ACK
  |
  +---- NACK ----> STOP ----> DONE
  |
 ACK
  |
  v
SEND DATA
  |
  v
DATA ACK
  |
  +---- NACK ----> STOP ----> DONE
  |
 ACK
  |
  v
STOP
  |
  v
DONE
  |
  v
IDLE
```

### Read Transaction

Representative one-byte read sequence:

```text
IDLE
  |
  v
START
  |
  v
SEND ADDRESS + READ
  |
  v
ADDRESS ACK
  |
  +---- NACK ----> STOP ----> DONE
  |
 ACK
  |
  v
READ DATA
  |
  v
MASTER NACK
  |
  v
STOP
  |
  v
DONE
  |
  v
IDLE
```

The controller generates NACK after the final received byte to indicate
that no additional data is requested.

---

## Bit / Timing Engine

The bit/timing engine is responsible for generating correct I2C bit
timing independently from the higher-level transaction FSM.

A conceptual four-phase structure is used for each transferred bit.

```text
Q0          Q1             Q2            Q3
SCL LOW     Release SCL    SCL HIGH      Return LOW
Set SDA     Wait for HIGH  Sample/hold
```

### Q0 — SCL LOW

During this phase:

- SCL is actively pulled LOW;
- SDA is prepared for the next transmitted bit when transmitting;
- setup timing is established.

### Q1 — Release SCL

The controller releases SCL.

The controller must observe `scl_in`.

The phase does not advance simply because the controller released SCL.

If another device holds SCL LOW, the controller waits.

This is the mechanism used to support legal clock stretching.

### Q2 — SCL HIGH

When actual SCL is observed HIGH:

- the HIGH timing interval is maintained;
- SDA is sampled when receiving;
- acknowledgement values can be sampled;
- transmitted SDA remains stable as required.

### Q3 — Return SCL LOW

The controller pulls SCL LOW again and prepares for the next bit.

The exact counter implementation will be frozen during RTL design.

---

## Open-Drain Bus Interface

The controller core does not directly drive logic HIGH onto SDA or SCL.

Instead it controls whether each line is actively pulled LOW or
released.

Core control signals:

```systemverilog
sda_drive_low
scl_drive_low
```

Meaning:

```text
sda_drive_low = 1 -> actively pull SDA LOW
sda_drive_low = 0 -> release SDA

scl_drive_low = 1 -> actively pull SCL LOW
scl_drive_low = 0 -> release SCL
```

The FPGA/top-level wrapper may represent the physical open-drain
behavior using:

```systemverilog
assign sda = sda_drive_low ? 1'b0 : 1'bz;
assign scl = scl_drive_low ? 1'b0 : 1'bz;
```

The actual bus levels are returned to the controller through:

```systemverilog
sda_in
scl_in
```

This separation is important because:

- another target may pull SDA LOW;
- another target may stretch SCL LOW;
- the future fault injector may force SDA or SCL LOW;
- the controller must react to actual bus state rather than only its own
  output intent.

---

## Timing Parameters

The initial configuration is:

```text
System clock = 100 MHz
I2C SCL      = nominal 100 kHz
Mode         = Standard-mode
```

The timing implementation must be parameterized rather than hard-coded.

Initial architectural parameters should include:

```systemverilog
parameter integer SYS_CLK_HZ = 100_000_000;
parameter integer I2C_CLK_HZ = 100_000;
```

Derived or configurable timing values will include where required:

```text
T_LOW_CYCLES
T_HIGH_CYCLES
T_HD_STA_CYCLES
T_SU_STA_CYCLES
T_SU_STO_CYCLES
T_BUF_CYCLES
```

For a conceptual four-phase timing engine:

```text
100 MHz / (100 kHz x 4)
= approximately 250 system-clock cycles per quarter phase
```

The final values must satisfy the documented Standard-mode timing
requirements.

The implementation must not assume that changing `I2C_CLK_HZ` alone is
sufficient for every future I2C mode.

Fast-mode and Fast-mode Plus will require separate timing validation
before they can be claimed as supported.

Standard-mode is the only frozen validation target for the current
project.

---

## Clock-Stretch Behavior

The baseline must support legal I2C clock stretching.

When the controller wants SCL HIGH:

```text
scl_drive_low = 0
```

the controller releases the line.

It must then inspect:

```text
scl_in
```

If `scl_in` remains LOW, the controller waits.

Conceptually:

```text
release SCL
    |
    v
observe scl_in
    |
    +---- LOW ----> wait
    |
    +---- HIGH ---> continue SCL HIGH phase
```

### Baseline Behavior

The baseline contains no project-defined timeout.

Therefore it may wait indefinitely for legal or indefinitely prolonged
SCL LOW.

This is deliberate.

The fault-aware design will later use the same protocol behavior plus a
configurable F2 loss-of-progress monitor.

This creates a fair baseline-versus-proposed comparison.

---

## NACK Behavior

NACK is legal I2C protocol behavior and is not classified as a primary
fault condition in this project.

The baseline must correctly detect target-generated NACK.

### Address NACK

If the address phase receives NACK:

```text
ADDRESS NACK
     |
     v
set nack status
     |
     v
generate STOP
     |
     v
DONE
```

### Write-Data NACK

If the transmitted data byte receives NACK:

```text
DATA NACK
    |
    v
set nack status
    |
    v
generate STOP
    |
    v
DONE
```

### Read Completion

For a one-byte read, the controller generates NACK after receiving the
final byte and then generates STOP.

Retry logic is not required as part of the primary baseline experiment.

---

## Bus-Free Behavior

The baseline must observe the externally visible bus state.

A free bus requires:

```text
SDA = HIGH
SCL = HIGH
```

A new independent transaction must not start until the applicable
bus-free timing requirement has been satisfied.

Following STOP, the controller must respect `tBUF` before beginning a
new independent START.

### Baseline Limitation

If SDA remains LOW when the controller expects a free bus, the baseline
does not perform automatic bus-clear recovery.

This is intentional.

F1 SDA-stuck detection and recovery are part of the fault-aware design.

---

## Matched-Comparison Rule

The baseline and fault-aware designs must remain architecturally matched.

The intended comparison is:

```text
BASELINE

Host Interface
     |
Transaction FSM
     |
Bit / Timing Engine
     |
Open-Drain Interface
```

versus:

```text
FAULT-AWARE

Same Host Interface
     |
Same Transaction FSM
     |
Same Bit / Timing Engine
     |
Same Open-Drain Interface
     |
+ Bus Monitor
+ F1 Detector
+ F2 Detector
+ Fault Classifier
+ Recovery / Containment Controller
+ Fault Status
```

The proposed design must not be independently redesigned in a way that
makes the FPGA comparison unfair.

The measured differences should represent, as closely as possible, the
incremental cost of the fault-management extension.

Both implementations must later use:

- the same FPGA part;
- Vivado 2024.1;
- the same system-clock constraint;
- the same synthesis strategy;
- the same implementation strategy;
- the same relevant RTL parameters.

---

## Baseline Verification Gate

The baseline RTL cannot be considered complete until the automated
regression demonstrates all required normal behaviors.

Minimum baseline tests:

```text
RESET / IDLE                 PASS
BUS FREE                     PASS
START                        PASS
ONE-BYTE WRITE + ACK         PASS
ADDRESS NACK                 PASS
WRITE-DATA NACK              PASS
ONE-BYTE READ                PASS
MASTER FINAL NACK            PASS
STOP                         PASS
LEGAL CLOCK STRETCH          PASS
tBUF                         PASS
STANDARD-MODE TIMING         PASS
REPEATED REGRESSION          PASS
```

The regression must not rely only on visual waveform inspection.

The final verification environment should automatically determine
PASS/FAIL wherever practical.

The baseline must also have:

- no unexplained FSM deadlock;
- no unexplained X behavior;
- correct open-drain behavior;
- correct observation of externally stretched SCL;
- reproducible results.

Fault-aware RTL development must not proceed while the baseline has an
unresolved functional or timing mismatch.

---

## Reproducibility

The baseline experiment must be reproducible from a clean repository
checkout.

The final project must document:

- Git commit / RTL revision;
- Vivado version;
- target FPGA part;
- system-clock frequency;
- I2C configuration;
- design parameters;
- simulator command or Tcl script;
- synthesis command or Tcl script;
- timing constraints;
- test names;
- random seeds where applicable;
- preserved automated result output.

The initial frozen implementation environment is:

```text
Tool              : Vivado 2024.1
Simulator         : Vivado Simulator / XSIM
RTL               : SystemVerilog
FPGA family       : Artix-7
FPGA part         : XC7A35T-1CPG236C
Reference board   : Basys 3
System clock      : 100 MHz
I2C mode          : Standard-mode
Nominal SCL       : 100 kHz
Addressing        : 7-bit
```

No physical Basys 3 hardware is currently available.

Therefore later results may be described as simulation, synthesis, and
implementation results targeting the XC7A35T-1CPG236C device.

The project must not claim physical Basys 3 hardware validation unless
an actual board is used.