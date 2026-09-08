# Verification Plan

## Status

This verification plan is defined after closure of the S3 architecture stage.

It specifies how the baseline and fault-aware FPGA I2C master controllers
will be verified before implementation results are accepted.

The verification environment uses SystemVerilog and Vivado Simulator
(XSIM).

UVM is not required for the current project.

The verification strategy combines:

- deterministic directed tests;
- self-checking SystemVerilog testbench components;
- a behavioral I2C target model;
- controlled SDA/SCL fault injection;
- assertions where supported by XSIM;
- procedural protocol checkers where appropriate;
- scoreboard-based functional checking;
- explicit functional and fault-coverage counters;
- detection/recovery latency measurement;
- automated PASS/FAIL regression.

The verification environment must not depend only on manual waveform
inspection.

Waveforms may be used for debugging, but final acceptance must be based on
automated checks.

---

# 1. Verification Objectives

The verification environment must establish four main properties.

## 1.1 Baseline Functional Correctness

The conventional baseline controller must correctly perform its frozen
Standard-mode I2C functionality before fault-aware RTL is evaluated.

Required baseline behavior includes:

- reset and IDLE operation;
- bus-free qualification;
- START;
- 7-bit addressing;
- one-byte write;
- one-byte read;
- ACK detection;
- address NACK handling;
- write-data NACK handling;
- controller NACK after the final read byte;
- STOP;
- legal clock stretching;
- Standard-mode timing;
- `tBUF`;
- open-drain SDA/SCL behavior.

---

## 1.2 Fault-Aware Normal-Operation Equivalence

When no supported fault is injected, the fault-aware controller must behave
functionally like the matched baseline controller.

The added F1/F2 hardware must not alter normal:

- transaction data;
- ACK/NACK behavior;
- START/STOP behavior;
- SCL frequency;
- bus timing;
- read/write results;
- normal transaction latency except for demonstrably unavoidable
  implementation effects.

---

## 1.3 F1/F2 Fault Handling

The fault-aware controller must demonstrate the behavior frozen during S3.

### F1

The environment must verify:

- SDA-stuck-LOW detection only in valid free-bus context;
- exact threshold behavior;
- no false F1 during legal SDA LOW;
- exactly nine recovery clocks during normal F1 recovery;
- first SDA-release pulse measurement;
- successful bus-free qualification after recovery;
- recovery failure when SDA never releases;
- post-recovery transaction operation.

### F2

The environment must verify:

- detection only while the controller released SCL and expects SCL HIGH;
- no counting during controller-driven SCL LOW;
- legal clock stretching below the configured threshold;
- exact threshold-boundary behavior;
- safe transaction containment;
- release of both open-drain outputs;
- no attempt to force SCL HIGH;
- wait for external SCL release;
- bus-free and `tBUF` qualification;
- post-containment transaction operation.

---

## 1.4 Quantitative Measurements

The verification environment must collect quantitative data suitable for
later experimental analysis.

Measurements include:

- F1 detection latency;
- F2 detection latency;
- F1 recovery latency;
- F1 first SDA-release pulse;
- F1 recovery success/failure;
- F2 containment response latency;
- F2 return-to-service latency;
- false-positive count;
- post-recovery transaction success;
- number of tests passed/failed.

---

# 2. Frozen Verification Configuration

The primary verification configuration is:

```text
Tool                 : Vivado 2024.1
Simulator            : Vivado Simulator / XSIM
RTL language         : SystemVerilog
FPGA family          : Artix-7
Target FPGA          : XC7A35T-1CPG236C
System clock         : 100 MHz
System-clock period  : 10 ns
I2C mode             : Standard-mode
Nominal SCL          : 100 kHz
Addressing           : 7-bit
Topology             : Single controller
Transaction width    : One byte
```

The primary target model address will provisionally be:

```text
7-bit target address = 0x50
```

The exact address is not architecturally significant and may be changed
consistently if required.

---

# 3. Experimental Fault Thresholds

The fault thresholds are project implementation parameters.

They are not mandatory timeout values defined by base I2C.

The initial primary experimental configuration is:

```text
SYS_CLK_HZ                = 100,000,000
SDA_STUCK_LIMIT_CYCLES    = 10,000
SCL_STALL_LIMIT_CYCLES    = 100,000
```

At a 100 MHz system clock:

```text
SDA_STUCK_LIMIT_CYCLES = 10,000
                       = 100 us

SCL_STALL_LIMIT_CYCLES = 100,000
                       = 1 ms
```

The F2 threshold is intentionally longer than the F1 persistence threshold
so that the controller tolerates substantial legal clock stretching before
classifying loss of progress.

These values are project experimental defaults and must not be described as
I2C specification requirements.

The RTL must remain parameterized so alternative thresholds can later be
tested without redesign.

---

# 4. Threshold Semantics

Both fault detectors use the S3 frozen consecutive-sample convention.

For:

```text
LIMIT = N
```

the behavior is:

```text
qualifying sample 1       -> no fault
qualifying sample N - 1   -> no fault
qualifying sample N       -> fault asserted
```

If the qualifying condition disappears before sample N:

```text
counter -> 0
```

This rule applies to both:

```text
SDA_STUCK_LIMIT_CYCLES
SCL_STALL_LIMIT_CYCLES
```

The testbench must explicitly verify the `LIMIT - 1`, `LIMIT`, and
`LIMIT + 1` boundaries.

---

# 5. Testbench Architecture

The verification environment will use the following conceptual structure.

```text
                       +-------------------+
                       |  Test Sequencer   |
                       +---------+---------+
                                 |
                                 | host command
                                 v
                     +-----------------------+
                     |                       |
                     |       I2C DUT         |
                     | baseline/fault-aware  |
                     |                       |
                     +----------+------------+
                                |
                             SDA / SCL
                                |
                +---------------+---------------+
                |                               |
                v                               v
        +---------------+                +---------------+
        | I2C Target    |                | Fault Injector|
        | Model         |                |               |
        |               |                | SDA hold LOW  |
        | ACK/NACK      |                | SCL hold LOW  |
        | read data     |                | timed release |
        | clock stretch |                | pulse release |
        +-------+-------+                +-------+-------+
                |                                |
                +----------------+---------------+
                                 |
                                 v
                       +------------------+
                       |   Bus Monitor    |
                       +--------+---------+
                                |
                 +--------------+--------------+
                 |                             |
                 v                             v
           +-----------+                +-------------+
           | Scoreboard|                | Assertions  |
           +-----+-----+                | / Checkers  |
                 |                      +------+------+
                 +--------------+--------------+
                                |
                                v
                       +------------------+
                       | Coverage /       |
                       | Measurements     |
                       +--------+---------+
                                |
                                v
                        Automated PASS/FAIL
```

---

# 6. Proposed Testbench File Organization

The eventual testbench structure should use:

```text
tb/
├── common/
│   ├── i2c_target_model.sv
│   ├── i2c_bus_monitor.sv
│   ├── i2c_scoreboard.sv
│   ├── fault_injector.sv
│   └── verification_counters.sv
│
├── assertions/
│   └── i2c_assertions.sv
│
├── baseline/
│   └── tb_i2c_master_baseline.sv
│
├── fault_aware/
│   └── tb_i2c_master_fault_aware.sv
│
└── smoke/
    └── tb_xsim_sv_features.sv
```

The exact file partition may change slightly during implementation, but the
logical responsibilities must remain separated.

---

# 7. Open-Drain Bus Modeling

The testbench must model SDA and SCL as shared open-drain buses.

The DUT, target model, and fault injector are each allowed only to:

```text
pull LOW
or
release
```

They must never actively drive HIGH.

A conceptual SystemVerilog structure is:

```systemverilog
tri1 sda_bus;
tri1 scl_bus;

assign sda_bus = dut_sda_drive_low    ? 1'b0 : 1'bz;
assign sda_bus = target_sda_drive_low ? 1'b0 : 1'bz;
assign sda_bus = fault_sda_drive_low  ? 1'b0 : 1'bz;

assign scl_bus = dut_scl_drive_low    ? 1'b0 : 1'bz;
assign scl_bus = target_scl_drive_low ? 1'b0 : 1'bz;
assign scl_bus = fault_scl_drive_low  ? 1'b0 : 1'bz;
```

The DUT observes:

```systemverilog
sda_in = sda_bus;
scl_in = scl_bus;
```

This permits:

- normal target ACK generation;
- target read-data transmission;
- target clock stretching;
- SDA-stuck injection;
- SCL-stall injection;
- realistic wired-AND behavior.

---

# 8. Host Test Sequencer

The host sequencer drives the DUT command interface.

Required command tasks should conceptually include:

```systemverilog
task issue_write(
    input logic [6:0] address,
    input logic [7:0] data
);

task issue_read(
    input logic [6:0] address
);
```

The sequencer must:

1. wait for `cmd_ready`;
2. apply command fields;
3. assert `cmd_valid`;
4. wait for command acceptance;
5. deassert `cmd_valid`;
6. wait for completion or defined fault handling;
7. pass observed results to the scoreboard.

The sequencer must never assume fixed transaction completion time when clock
stretching or fault handling is active.

---

# 9. I2C Target Model

The behavioral target model must support only the features required by the
research experiment.

Required capabilities:

- respond to one 7-bit address;
- ACK valid address;
- optionally NACK address;
- ACK received write byte;
- optionally NACK write data;
- receive and record one write byte;
- transmit one configured read byte;
- observe controller final NACK;
- generate controlled legal clock stretching;
- release SDA/SCL normally when inactive.

The target model does not need to implement an entire commercial I2C
peripheral.

Its purpose is deterministic verification of the controller.

---

# 10. Target Model Data Behavior

The target model should contain a simple one-byte data register.

Example:

```text
target_data = 8'hA5
```

### Write

For a successful write:

```text
host command data
        ->
DUT
        ->
I2C bus
        ->
target received byte
```

The scoreboard must check that the target received the expected byte.

### Read

For a successful read:

```text
target configured byte
        ->
I2C bus
        ->
DUT read_data
```

The scoreboard must compare:

```text
DUT read_data == expected target data
```

Multiple data patterns should be used during regression.

Recommended patterns:

```text
8'h00
8'hFF
8'hAA
8'h55
8'h01
8'h80
8'h3C
8'hA5
```

---

# 11. Fault Injector

The fault injector is independent of the normal I2C target model.

This distinction is important.

Legal target behavior and deliberate abnormal conditions must not be mixed
into a single uncontrolled model.

The injector conceptually controls:

```systemverilog
fault_sda_drive_low
fault_scl_drive_low
```

Required operations include:

```text
hold SDA LOW
release SDA

hold SCL LOW
release SCL
```

The injector must support deterministic release conditions such as:

```text
release SDA after recovery pulse 1
release SDA after recovery pulse 3
release SDA after recovery pulse 5
release SDA after recovery pulse 9
never release SDA
```

For F2 it must support:

```text
hold SCL for fixed number of system-clock samples
hold SCL indefinitely
release SCL after fault detection
```

---

# 12. Bus Monitor

The bus monitor observes actual SDA and SCL independently of the DUT.

It must identify where practical:

- START;
- STOP;
- SCL rising edges;
- SCL falling edges;
- address byte;
- R/W bit;
- ACK/NACK;
- transmitted data;
- received data;
- recovery clock pulses.

The monitor must not rely only on internal DUT state.

This provides an independent protocol-level observation path.

---

# 13. Scoreboard

The scoreboard compares expected behavior against observed behavior.

The scoreboard must check at least:

### Write transaction

```text
expected address
expected R/W = WRITE
expected data
expected ACK/NACK result
expected completion status
```

### Read transaction

```text
expected address
expected R/W = READ
expected target byte
DUT read_data
expected controller final NACK
expected completion status
```

### Fault-aware transaction

The scoreboard must additionally check:

```text
expected fault code
expected recovery outcome
expected pulse count
expected post-recovery state
expected command completion behavior
```

Any mismatch increments a global error counter.

---

# 14. Test Result Convention

Every individual test must end with exactly one logical result:

```text
PASS
or
FAIL
```

Recommended format:

```text
[PASS] B03_ONE_BYTE_READ
```

or:

```text
[FAIL] F2_03_THRESHOLD_EXACT : expected FAULT_SCL_STALL
```

At regression completion:

```text
========================================
TOTAL TESTS : N
PASSED      : P
FAILED      : F
========================================
REGRESSION  : PASS
========================================
```

The regression passes only when:

```text
FAILED = 0
```

---

# 15. Baseline Directed Test Matrix

The baseline must pass before the fault-aware RTL is allowed to close.

## B01 — Reset and Idle

Verify:

```text
reset asserted
outputs released
busy = 0
cmd_ready eventually = 1 when bus free
no false done
no false nack
```

---

## B02 — Successful One-Byte Write

Example:

```text
address = 0x50
data    = 0xA5
```

Verify:

- START;
- correct address + write bit;
- address ACK;
- correct data byte;
- data ACK;
- STOP;
- `done`;
- no `nack`;
- target receives `0xA5`.

---

## B03 — Successful One-Byte Read

Configure target:

```text
read data = 0x3C
```

Verify:

- START;
- correct address + read bit;
- address ACK;
- correct received byte;
- DUT reports `read_data = 0x3C`;
- controller sends final NACK;
- STOP;
- successful completion.

---

## B04 — Address NACK

The target intentionally NACKs the address.

Verify:

```text
nack = 1
STOP generated
done generated
controller returns IDLE
```

---

## B05 — Write-Data NACK

The target ACKs the address and NACKs the write data.

Verify:

```text
nack = 1
STOP generated
transaction terminates cleanly
```

---

## B06 — Legal Clock Stretch

The target holds SCL LOW after the controller releases SCL.

The stretch duration must be clearly below the future F2 threshold.

Verify:

```text
controller waits
transaction does not advance prematurely
transaction resumes after release
final data is correct
```

---

## B07 — Bus-Free / tBUF

After STOP, attempt another command.

Verify that the next independent START does not occur before the configured
`tBUF` requirement completes.

---

## B08 — Back-to-Back Transactions

Execute:

```text
WRITE
READ
WRITE
READ
```

Verify clean return to IDLE and correct command acceptance between
transactions.

---

## B09 — Data Pattern Regression

Repeat write/read operation using:

```text
00
FF
AA
55
01
80
3C
A5
```

Verify all values correctly.

---

## B10 — Open-Drain Behavior

Verify that the controller never requires an actively driven HIGH level on
SDA or SCL.

Released lines may be held LOW by the target.

---

# 16. Baseline Exit Gate

The baseline verification gate passes only if:

```text
B01 PASS
B02 PASS
B03 PASS
B04 PASS
B05 PASS
B06 PASS
B07 PASS
B08 PASS
B09 PASS
B10 PASS
```

All failures must be diagnosed before fault-aware implementation is accepted.

---

# 17. Fault-Aware Normal-Operation Tests

Before injecting faults, repeat the baseline tests against the fault-aware
controller.

Test IDs:

```text
N01 -> reset / idle
N02 -> write
N03 -> read
N04 -> address NACK
N05 -> data NACK
N06 -> legal stretch
N07 -> tBUF
N08 -> data-pattern regression
```

Required result:

```text
all normal tests PASS
fault_active = 0
recovery_active = 0
recovery_failed = 0
```

This demonstrates that the added fault-management layer does not interfere
with normal operation.

---

# 18. F1 Detection Tests

## F1_01 — Short SDA LOW Below Threshold

While the controller expects a free bus, force:

```text
SCL HIGH
SDA LOW
```

for substantially less than:

```text
SDA_STUCK_LIMIT_CYCLES
```

Then release SDA.

Expected:

```text
no F1
no recovery
```

---

## F1_02 — Threshold Minus One

Hold the exact F1 qualifying condition for:

```text
SDA_STUCK_LIMIT_CYCLES - 1
```

qualifying samples.

Expected:

```text
fault_active = 0
```

---

## F1_03 — Exact Threshold

Hold the qualifying condition for exactly:

```text
SDA_STUCK_LIMIT_CYCLES
```

qualifying samples.

Expected:

```text
fault_active = 1
fault_code   = FAULT_SDA_STUCK
```

on the frozen threshold boundary.

---

## F1_04 — Threshold Plus One

Continue the condition beyond detection.

Expected:

```text
F1 remains classified
recovery proceeds
```

No second fault event should be generated for the same persistent
condition.

---

# 19. F1 False-Positive Tests

F1 must not trigger merely because SDA is LOW during legal I2C activity.

The testbench must check SDA LOW during:

```text
START
address bit = 0
write-data bit = 0
target ACK
read-data bit = 0
controller-controlled bus activity
```

Expected:

```text
!(fault_active && fault_code == FAULT_SDA_STUCK)
```

during these legal phases.

---

# 20. F1 Recovery Tests

The recovery injector records SCL recovery clocks and controls SDA release.

## F1_R01 — SDA Releases on Pulse 1

SDA is held LOW until the first recovery clock.

The injector releases SDA at the defined pulse-1 observation point.

Expected:

```text
first_sda_release_pulse = 1
total completed recovery clocks = 9
recovery succeeds
```

---

## F1_R03 — SDA Releases on Pulse 3

Expected:

```text
first_sda_release_pulse = 3
total completed recovery clocks = 9
recovery succeeds
```

---

## F1_R05 — SDA Releases on Pulse 5

Expected:

```text
first_sda_release_pulse = 5
total completed recovery clocks = 9
recovery succeeds
```

---

## F1_R09 — SDA Releases on Pulse 9

Expected:

```text
first_sda_release_pulse = 9
total completed recovery clocks = 9
recovery succeeds
```

---

## F1_RF — SDA Never Releases

Keep SDA LOW through all nine completed recovery clocks.

Expected:

```text
total recovery clocks = 9
recovery_failed = 1
fault_code = FAULT_SDA_STUCK
cmd_ready = 0
```

The controller must not silently return to normal operation.

---

# 21. F1 Post-Recovery Test

Following successful F1 recovery:

1. wait until recovery finishes;
2. confirm bus free;
3. confirm `tBUF`;
4. submit a fresh normal command.

Recommended operation:

```text
WRITE 0xA5
then READ known data
```

Expected:

```text
transaction PASS
```

This proves that bus recovery is not merely a status transition and that
the controller actually returns to usable service.

---

# 22. F2 Clock-Stretch / Stall Tests

## F2_01 — Short Legal Stretch

Hold SCL LOW for a duration substantially below:

```text
SCL_STALL_LIMIT_CYCLES
```

Expected:

```text
no F2
transaction resumes
transaction PASS
```

---

## F2_02 — Threshold Minus One

Hold SCL LOW for:

```text
SCL_STALL_LIMIT_CYCLES - 1
```

qualifying samples.

Expected:

```text
fault_active = 0
```

Release SCL and verify normal transaction completion.

---

## F2_03 — Exact Threshold

Hold SCL LOW for exactly:

```text
SCL_STALL_LIMIT_CYCLES
```

qualifying samples after the controller has released SCL.

Expected:

```text
fault_active = 1
fault_code = FAULT_SCL_STALL
```

---

## F2_04 — Threshold Plus One

Continue holding SCL LOW after detection.

Expected:

```text
controller remains contained
SDA released
SCL released by controller
no normal transaction progress
```

---

## F2_05 — Extended / Indefinite Hold

Hold SCL LOW for an extended interval after F2 detection.

Verify:

```text
no attempt to force SCL HIGH
controller remains contained
new commands remain blocked
```

Then release SCL.

---

## F2_06 — External Release After Detection

Following F2 detection:

```text
release externally held SCL
```

Then permit SDA/SCL to become free.

Expected:

```text
WAIT_BUS_FREE
WAIT_TBUF
return to service
```

The interrupted transaction must not resume from its previous bit.

---

# 23. F2 False-Positive Tests

## F2_FP01 — Controller's Own LOW Phase

During normal SCL LOW generation:

```text
scl_drive_low = 1
```

Verify the F2 detector counter does not classify a fault.

---

## F2_FP02 — Legal Stretch Below Threshold

Exercise several legal stretch durations below the configured threshold.

Recommended durations:

```text
1 system-clock sample
10 samples
100 samples
1,000 samples
LIMIT / 4
LIMIT / 2
LIMIT - 1
```

All must complete without F2.

---

# 24. F2 Post-Containment Test

Following successful F2 containment and external release:

1. confirm SCL HIGH;
2. confirm SDA HIGH;
3. complete `tBUF`;
4. confirm `cmd_ready`;
5. issue a fresh normal transaction.

Expected:

```text
new transaction PASS
```

The interrupted transaction must not be automatically retried.

---

# 25. F1-to-F2 Interaction Test

A specific compound interaction is required because S3 explicitly defines
F2 preemption during F1 recovery.

Test ID:

```text
F12_01
```

Procedure:

1. create F1 by holding SDA LOW while the bus is expected free;
2. allow F1 detection;
3. allow F1 recovery to begin;
4. when the controller releases SCL for a recovery pulse, externally hold
   SCL LOW;
5. maintain SCL LOW for `SCL_STALL_LIMIT_CYCLES`.

Expected:

```text
F1 recovery is abandoned
FAULT_SDA_STUCK is replaced by FAULT_SCL_STALL
only one active fault code exists
SDA released
SCL released by controller
F2 containment entered
```

After external SCL release and valid bus-free qualification:

```text
controller returns to service
```

This is the only mandatory compound-fault interaction in the primary
experiment.

---

# 26. Fault Status Tests

The status policy defined in S3 must be verified.

## Successful F1/F2 Handling

After successful recovery/containment:

```text
recovery_active = 0
recovery_failed = 0
fault_active remains visible
fault_code remains latched
```

When the next command is successfully accepted:

```text
fault_active -> 0
fault_code   -> FAULT_NONE
```

---

## Failed F1

Following unrecovered SDA stuck LOW:

```text
fault_active     = 1
fault_code       = FAULT_SDA_STUCK
recovery_failed  = 1
cmd_ready        = 0
```

These values remain latched until reset.

---

# 27. Assertions and Protocol Checkers

Assertions should be used for simple and high-value temporal properties.

Before relying on advanced SVA syntax, a small XSIM feature smoke-test must
confirm the supported subset.

Properties should include where practical:

### A01 — No command while busy

A new command must not be accepted while the controller is already busy.

### A02 — No command during recovery

```text
recovery_active -> cmd_ready == 0
```

### A03 — Failed recovery blocks commands

```text
recovery_failed -> cmd_ready == 0
```

### A04 — F1 valid context

F1 must only be generated from the defined free-bus monitoring context.

### A05 — No F2 while controller drives SCL LOW

```text
scl_drive_low == 1
->
F2 counter must not progress toward classification
```

### A06 — F2 containment releases outputs

After F2 containment ownership begins:

```text
sda_drive_low = 0
scl_drive_low = 0
```

subject to the exact selected internal/top-level observation point.

### A07 — F1 recovery maximum/total clock rule

Normal F1 recovery that is not preempted by F2 must complete exactly nine
recovery clocks.

### A08 — F1 failure

If SDA remains LOW after recovery clock 9:

```text
recovery_failed = 1
```

### A09 — No simultaneous F1 and F2 classification

Only one fault code may be active.

### A10 — Done pulse width

If `done` is designed as a pulse, verify it remains asserted for exactly one
system-clock cycle.

### A11 — Recovery success requires bus qualification

The controller must not report return to normal service before the required
bus-free interval has completed.

### A12 — Post-reset safe release

Following reset, SDA and SCL must be released until normal protocol activity
requires a LOW.

Complex checks that are awkward or unsupported in XSIM SVA may be implemented
using deterministic procedural checkers.

---

# 28. XSIM SystemVerilog Feature Smoke Test

Before the main verification environment depends on simulator-specific
features, create a small smoke test.

File:

```text
tb/smoke/tb_xsim_sv_features.sv
```

It should test whether Vivado 2024.1 XSIM supports the required usage of:

- `assert property`;
- simple `sequence` / `property`;
- `$error`;
- `$fatal`;
- tasks;
- structs/enums if used;
- queues if used;
- covergroups if considered;
- randomization only if later required.

If a non-essential language feature is unsupported, the verification plan
must use a simpler SystemVerilog mechanism rather than changing simulator.

UVM remains outside the required project scope.

---

# 29. Coverage Strategy

Coverage must answer whether the selected research space has actually been
exercised.

Native simulator coverage may be used where supported, but project closure
must not depend on a feature that XSIM cannot provide reliably.

Therefore explicit SystemVerilog counters are the minimum required coverage
mechanism.

---

# 30. Functional Coverage Counters

Required normal-operation coverage includes:

```text
write_success
read_success
address_nack
data_nack
legal_clock_stretch
tbuf_checked
all_data_patterns
```

Each item must be exercised at least once.

---

# 31. F1 Coverage

Required F1 coverage points:

```text
F1 below threshold
F1 LIMIT - 1
F1 exact LIMIT
F1 LIMIT + 1
F1 false-positive checks
release pulse 1
release pulse 3
release pulse 5
release pulse 9
never release
successful recovery
failed recovery
post-recovery success
```

---

# 32. F2 Coverage

Required F2 coverage points:

```text
short legal stretch
LIMIT - 1
exact LIMIT
LIMIT + 1
extended hold
release after detection
controller-driven SCL LOW excluded
successful return to service
post-containment transaction success
```

---

# 33. Interaction Coverage

Required interaction coverage:

```text
F1 recovery begins
SCL becomes stalled
F2 threshold reached
classification changes to F2
F2 containment entered
eventual return to service
```

---

# 34. Coverage Matrix

The final regression should generate a machine-readable summary similar to:

```text
COVERAGE,RESULT
BASELINE_WRITE,1
BASELINE_READ,1
ADDRESS_NACK,1
DATA_NACK,1
LEGAL_STRETCH,1
F1_LIMIT_MINUS_1,1
F1_LIMIT,1
F1_RELEASE_1,1
F1_RELEASE_3,1
F1_RELEASE_5,1
F1_RELEASE_9,1
F1_FAILURE,1
F2_LIMIT_MINUS_1,1
F2_LIMIT,1
F2_EXTENDED,1
F2_RELEASE,1
F1_TO_F2_PREEMPTION,1
POST_F1_TRANSACTION,1
POST_F2_TRANSACTION,1
```

A value of:

```text
1
```

means the required condition was exercised and passed.

---

# 35. Detection Latency Definition

The first qualifying sample is designated:

```text
sample 1
```

and detection occurs at:

```text
sample LIMIT
```

Therefore the inclusive qualifying sample count is:

```text
LIMIT samples
```

while the elapsed time between the first qualifying sampling edge and the
detection sampling edge is:

```text
(LIMIT - 1) * Tclk
```

This distinction must be preserved in results to avoid off-by-one ambiguity.

---

# 36. F1 Latency Metrics

Record:

```text
T_F1_ONSET
T_F1_DETECT
T_F1_RECOVERY_START
T_F1_RECOVERY_COMPLETE
FIRST_SDA_RELEASE_PULSE
```

Derived measurements:

```text
F1_detection_latency =
    T_F1_DETECT - T_F1_ONSET

F1_recovery_latency =
    T_F1_RECOVERY_COMPLETE - T_F1_DETECT
```

The first SDA-release pulse is reported separately.

Because normal F1 recovery completes nine clocks even when SDA releases
earlier, first-release pulse and total recovery completion latency are
different metrics.

---

# 37. F2 Latency Metrics

Record:

```text
T_F2_ONSET
T_F2_DETECT
T_OUTPUTS_RELEASED
T_EXTERNAL_SCL_RELEASE
T_F2_SERVICE_RESTORED
```

Derived measurements:

```text
F2_detection_latency =
    T_F2_DETECT - T_F2_ONSET

F2_containment_response_latency =
    T_OUTPUTS_RELEASED - T_F2_DETECT

F2_return_to_service_latency =
    T_F2_SERVICE_RESTORED - T_F2_DETECT
```

Because F2 return-to-service depends on external SCL release, this latency
must not be interpreted as purely controller internal latency.

The external-release delay should therefore also be preserved in the result
record.

---

# 38. False-Positive Metric

A false positive occurs when the DUT reports F1 or F2 during an exercised
condition that the test explicitly classifies as permitted behavior under
the selected project policy.

Examples include:

```text
normal SDA LOW during protocol
controller-driven SCL LOW
legal clock stretch below SCL_STALL_LIMIT_CYCLES
```

The primary regression requirement is:

```text
false_positive_count = 0
```

for all explicitly tested legal conditions.

This does not imply that every arbitrarily long legal I2C clock stretch can
be distinguished from F2.

A finite project-defined F2 threshold intentionally defines the point at
which the implementation classifies loss of progress.

---

# 39. Machine-Readable Result Format

Results should be preserved in a simple CSV format.

Proposed file:

```text
results/simulation/regression_results.csv
```

Suggested columns:

```text
test_id,
design,
result,
fault_code,
threshold_cycles,
fault_onset_cycle,
detect_cycle,
detection_latency_cycles,
recovery_start_cycle,
recovery_complete_cycle,
recovery_latency_cycles,
first_sda_release_pulse,
recovery_failed,
post_recovery_pass,
seed,
git_commit
```

Unused fields may be left blank for tests where they do not apply.

---

# 40. Regression Test List

Minimum baseline regression:

```text
B01_RESET_IDLE
B02_WRITE_ACK
B03_READ_ACK
B04_ADDRESS_NACK
B05_DATA_NACK
B06_LEGAL_CLOCK_STRETCH
B07_TBUF
B08_BACK_TO_BACK
B09_DATA_PATTERNS
B10_OPEN_DRAIN
```

Minimum fault-aware normal regression:

```text
N01_RESET_IDLE
N02_WRITE_ACK
N03_READ_ACK
N04_ADDRESS_NACK
N05_DATA_NACK
N06_LEGAL_STRETCH
N07_TBUF
N08_DATA_PATTERNS
```

Minimum F1 regression:

```text
F1_01_SHORT
F1_02_LIMIT_MINUS_1
F1_03_LIMIT
F1_04_LIMIT_PLUS_1
F1_FP_NORMAL_SDA_LOW
F1_R01_RELEASE_PULSE_1
F1_R03_RELEASE_PULSE_3
F1_R05_RELEASE_PULSE_5
F1_R09_RELEASE_PULSE_9
F1_RF_NEVER_RELEASE
F1_POST_RECOVERY
```

Minimum F2 regression:

```text
F2_01_SHORT_STRETCH
F2_02_LIMIT_MINUS_1
F2_03_LIMIT
F2_04_LIMIT_PLUS_1
F2_05_EXTENDED_HOLD
F2_06_EXTERNAL_RELEASE
F2_FP_MASTER_LOW
F2_FP_LEGAL_STRETCH
F2_POST_CONTAINMENT
```

Required interaction:

```text
F12_01_F1_TO_F2_PREEMPTION
```

---

# 41. Optional Seeded Stress Tests

Only after all deterministic tests pass, the project may add a small
seeded stress regression.

Possible variations include:

- randomized write data;
- randomized read data;
- randomized legal stretch duration below threshold;
- randomized F1 SDA release pulse from 1 through 9;
- randomized idle time between transactions.

Every run must preserve:

```text
seed
Git commit
test configuration
PASS/FAIL result
```

Seeded stress tests supplement the deterministic tests.

They do not replace them.

---

# 42. Automated Regression

The verification environment should eventually support execution through
Vivado Tcl or XSIM batch scripts.

Proposed scripts:

```text
scripts/run_baseline_sim.tcl
scripts/run_fault_aware_sim.tcl
scripts/run_regression.tcl
```

The scripts should:

1. compile the required SystemVerilog files;
2. elaborate the selected testbench;
3. run simulation;
4. return a non-zero failure status when a test fails where practical;
5. preserve simulation logs;
6. preserve result CSV files;
7. preserve relevant waveforms for failed tests;
8. print a concise summary.

The exact Vivado commands will be generated after the RTL/testbench file
structure exists.

---

# 43. Failure Handling

A test is considered failed if any of the following occurs:

- scoreboard mismatch;
- assertion failure;
- unexpected fault classification;
- missing expected fault classification;
- wrong recovery pulse count;
- wrong threshold boundary;
- incorrect transaction data;
- protocol deadlock;
- simulation timeout;
- unexplained X/Z behavior;
- unexpected command acceptance;
- missing post-recovery operation;
- incorrect fault-status persistence.

No failed test may be silently waived.

Any failure must be:

1. reproduced;
2. diagnosed;
3. corrected or explicitly identified as a real architectural blocker;
4. rerun;
5. passed before stage closure.

---

# 44. Simulation Watchdogs

Each test must include a finite simulation watchdog.

The watchdog prevents a broken DUT from causing an infinite simulation.

The timeout must be comfortably larger than the longest legitimate expected
operation.

F2 indefinite-hold tests must deliberately control when the fault injector
releases SCL rather than relying on an infinite simulation.

A watchdog timeout itself is a test failure unless the test explicitly
expects a latched failure state and verifies it before terminating.

---

# 45. Baseline / Fault-Aware Comparison

The baseline and fault-aware simulations must use equivalent:

- command sequences;
- target behavior;
- data values;
- Standard-mode timing assumptions;
- simulator version;
- testbench protocol model.

This prevents a comparison in which different verification environments
produce apparent behavioral differences.

Where possible, common testbench components must be shared.

---

# 46. Waveform Preservation

Waveforms are primarily a debug and evidence artifact.

For normal passing regression, preserving every large waveform is optional.

At minimum preserve waveforms for:

```text
representative baseline write
representative baseline read
F1 successful recovery
F1 failed recovery
F2 detection/containment
F1-to-F2 preemption
```

Failed tests should preserve their waveforms automatically when practical.

---

# 47. Reproducibility Requirements

Every final verification result must be traceable to:

```text
Git commit
Vivado version
XSIM version
target configuration
SYS_CLK_HZ
I2C_CLK_HZ
SDA_STUCK_LIMIT_CYCLES
SCL_STALL_LIMIT_CYCLES
test ID
seed where applicable
result
```

The project should be runnable from a clean repository checkout using
documented commands.

---

# 48. Evidence Rules

The final paper and README must distinguish:

```text
simulation result
synthesis result
implementation result
hardware-board result
```

Because no physical FPGA board is currently available, simulation success
must not be described as physical hardware validation.

Likewise:

```text
F2 threshold
```

must be described as an implementation-defined loss-of-progress policy, not
an I2C specification timeout.

---

# 49. S4 Verification Exit Criteria

S4 passes when the verification methodology is frozen and all of the
following are defined:

```text
[ ] Testbench architecture defined.
[ ] Open-drain bus model defined.
[ ] Host sequencer defined.
[ ] Target model behavior defined.
[ ] Fault injector behavior defined.
[ ] Bus monitor responsibility defined.
[ ] Scoreboard responsibility defined.
[ ] Baseline test matrix defined.
[ ] Fault-aware normal tests defined.
[ ] F1 threshold tests defined.
[ ] F1 recovery tests defined.
[ ] F1 failure test defined.
[ ] F1 false-positive tests defined.
[ ] F2 threshold tests defined.
[ ] F2 containment tests defined.
[ ] F2 false-positive tests defined.
[ ] F1-to-F2 interaction test defined.
[ ] Post-recovery tests defined.
[ ] Assertions/checkers defined.
[ ] Coverage model defined.
[ ] Detection-latency definitions frozen.
[ ] Recovery-latency definitions frozen.
[ ] Machine-readable result format defined.
[ ] Automated regression strategy defined.
[ ] Simulation watchdog policy defined.
[ ] Reproducibility requirements defined.
```

---

# 50. Gate Before RTL

Before baseline RTL begins, two additional checks are required.

## 50.1 Architecture-to-Verification Consistency Audit

Confirm that:

```text
fault_model.md
baseline_architecture.md
fault_aware_architecture.md
recovery_fsm.md
verification_plan.md
project_target.md
```

all describe the same:

- F1 condition;
- F2 condition;
- threshold convention;
- nine-clock recovery behavior;
- F1-to-F2 preemption;
- status behavior;
- return-to-service behavior.

## 50.2 XSIM Feature Smoke Test

Verify the SystemVerilog features actually required by the planned testbench.

Once both checks pass:

```text
S4 = PASS
```

and the project may proceed to:

```text
S5 — Baseline RTL Implementation
```

No fault-aware RTL should be written before the conventional baseline has
passed its required baseline regression.