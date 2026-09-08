# Fault-Aware Architecture

## Purpose

The fault-aware controller extends the matched baseline FPGA I2C master
with a small hardware fault-management layer.

The purpose of the extension is to detect and handle two selected abnormal
bus conditions:

- F1 — SDA stuck LOW;
- F2 — prolonged SCL LOW.

The fault-aware architecture must preserve all normal baseline behavior.

The proposed design must not replace the baseline protocol engine with an
independently redesigned controller.

The research objective is to measure the incremental behavior and FPGA
implementation cost introduced specifically by the added fault-management
logic.

The fault-aware controller therefore adds only the hardware required for:

- bus monitoring;
- F1 detection;
- F2 detection;
- fault classification;
- F1 autonomous bus-clear recovery;
- F2 safe containment;
- fault/recovery status;
- quantitative detection and recovery measurement.

---

## Relationship to Baseline

The proposed controller must use the same core protocol implementation as
the baseline wherever possible.

The shared baseline functionality includes:

- host command interface;
- transaction FSM;
- bit/timing engine;
- open-drain SDA/SCL interface;
- Standard-mode timing;
- 7-bit addressing;
- single-byte write;
- single-byte read;
- ACK/NACK handling;
- legal clock-stretch support;
- bus-free timing.

The conceptual comparison is:

```text
BASELINE

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

versus:

```text
FAULT-AWARE

Host Command Interface
        |
        v
Same Transaction FSM
        |
        v
Same Bit / Timing Engine
        |
        v
Same Open-Drain Bus Interface
        |
        v
      SDA / SCL
        ^
        |
+-------------------------+
| Fault-Management Layer  |
|                         |
| Bus Monitor             |
| F1 Detector             |
| F2 Detector             |
| Fault Classifier        |
| Recovery Controller     |
| Fault Status            |
+-------------------------+
```

The FPGA comparison must therefore represent the incremental cost of the
fault-management extension rather than differences between unrelated
controller implementations.

---

## Added Hardware Blocks

The fault-aware architecture adds the following logical blocks:

```text
                     Observed SDA / SCL
                            |
                            v
                    +---------------+
                    |   Bus Monitor |
                    +-------+-------+
                            |
              +-------------+-------------+
              |                           |
              v                           v
     +------------------+        +------------------+
     | F1 SDA Detector  |        | F2 SCL Detector  |
     +--------+---------+        +--------+---------+
              |                           |
              +-------------+-------------+
                            |
                            v
                   +------------------+
                   | Fault Classifier |
                   +--------+---------+
                            |
                            v
            +--------------------------------+
            | Recovery / Containment Control |
            +---------------+----------------+
                            |
               +------------+------------+
               |                         |
               v                         v
       F1 Bus-Clear Recovery      F2 Containment
               |                         |
               +------------+------------+
                            |
                            v
                  Fault / Recovery Status
```

These blocks must not interfere with normal I2C operation when no supported
abnormal condition exists.

---

## Bus Monitor

The bus monitor observes:

```systemverilog
sda_in
scl_in
sda_drive_low
scl_drive_low
```

and receives contextual information from the protocol engine.

Required contextual signals or internal conditions include conceptually:

```text
expect_bus_free
waiting_for_scl_high
transaction_active
controller_released_scl
```

The monitor must distinguish:

- actual bus state;
- controller output intent;
- legal protocol activity;
- candidate abnormal conditions.

The monitor must not classify a fault using SDA/SCL levels alone without
knowing the controller context.

For example:

```text
SDA LOW during data       -> normal
SDA LOW during ACK        -> normal
SCL LOW driven by master  -> normal
SCL LOW during legal stretch below threshold -> normal
```

---

## F1 SDA-Stuck Detector

### Purpose

F1 detects SDA remaining LOW when the controller expects the bus to be
free.

The detector must not trigger during normal protocol phases in which SDA
may legally be LOW.

### Detection Context

F1 monitoring is enabled only when:

```text
expect_bus_free = 1
```

and actual SCL is observed HIGH.

Conceptually:

```text
expect_bus_free
AND
scl_in == HIGH
AND
sda_in == LOW
```

starts or continues the F1 persistence counter.

### Persistence Counter

The condition must remain true continuously for:

```text
SDA_STUCK_LIMIT_CYCLES
```

before F1 is asserted.

Conceptually:

```text
if expect_bus_free &&
   scl_in == 1 &&
   sda_in == 0:

    sda_stuck_counter++

else:

    sda_stuck_counter = 0
```

When:

```text
sda_stuck_counter >= SDA_STUCK_LIMIT_CYCLES
```

the controller classifies:

```text
F1 = SDA_STUCK
```

### Conditions That Must Not Trigger F1

F1 must not be asserted merely because SDA is LOW during:

- START generation;
- address bits;
- transmitted data bits;
- received data bits;
- ACK;
- controller-generated SDA LOW;
- any other legal active-transaction state.

### F1 Detection Result

When F1 is detected:

```text
fault_active = 1
fault_code   = SDA_STUCK
```

and control is transferred to the F1 recovery sequence.

---

## F2 SCL-Stall Detector

### Purpose

F2 detects loss of progress when the controller has released SCL but actual
SCL remains LOW beyond a configurable implementation-defined threshold.

F2 must distinguish this condition from:

- the controller's own intentional SCL LOW phase;
- legal clock stretching below the configured threshold.

### Detection Context

F2 monitoring is enabled only when:

```text
waiting_for_scl_high = 1
```

and:

```text
scl_drive_low = 0
```

meaning that the controller has released SCL.

The monitored condition is:

```text
controller expects SCL HIGH
AND
controller is not driving SCL LOW
AND
scl_in == LOW
```

### Persistence Counter

Conceptually:

```text
if waiting_for_scl_high &&
   scl_drive_low == 0 &&
   scl_in == 0:

    scl_stall_counter++

else:

    scl_stall_counter = 0
```

When:

```text
scl_stall_counter >= SCL_STALL_LIMIT_CYCLES
```

the controller classifies:

```text
F2 = SCL_STALL
```

### Legal Clock Stretching

If SCL returns HIGH before the threshold is reached:

```text
scl_stall_counter = 0
```

and the normal baseline transaction continues.

Therefore:

```text
stretch duration < configured threshold
        ->
supported legal clock stretch
```

while:

```text
stretch duration >= configured threshold
        ->
project-defined F2 condition
```

The threshold is an implementation policy and must not be described as a
mandatory base-I2C timeout.

### F2 Detection Result

When F2 is detected:

```text
fault_active = 1
fault_code   = SCL_STALL
```

and control is transferred to the F2 containment sequence.

---

## Fault Classification

The initial architecture supports only two primary fault codes.

Recommended encoding:

```systemverilog
localparam logic [1:0] FAULT_NONE      = 2'b00;
localparam logic [1:0] FAULT_SDA_STUCK = 2'b01;
localparam logic [1:0] FAULT_SCL_STALL = 2'b10;
localparam logic [1:0] FAULT_RESERVED  = 2'b11;
```

The exact coding style may later use an enum.

### Classification Priority

If SCL is expected HIGH but actual SCL remains LOW, F2 classification takes
priority.

This is because F1 requires a valid SCL HIGH condition while the controller
expects the bus to be free.

Conceptually:

```text
if waiting_for_scl_high && scl_in == LOW:
        evaluate F2

else if expect_bus_free &&
        scl_in == HIGH &&
        sda_in == LOW:
        evaluate F1
```

The controller must not classify both faults simultaneously for the same
bus condition.

### Fault Scope

No additional primary fault class may be added during implementation
without reopening S2/S3 scope review.

Specifically excluded as primary faults:

- NACK by itself;
- arbitration loss;
- reset during transfer;
- glitches/noise;
- internal FPGA faults;
- Fast-mode timing faults;
- multi-controller conflicts.

---

## Recovery / Containment Controller

The recovery controller receives the selected fault classification and
executes the corresponding handling sequence.

The architecture intentionally uses different behavior for F1 and F2.

```text
F1 SDA_STUCK
    ->
active autonomous recovery attempt

F2 SCL_STALL
    ->
safe containment and controlled return to service
```

---

### F1 Recovery Sequence

The F1 controller performs an autonomous nine-clock bus-clear sequence.

Conceptually:

```text
F1 detected
    |
    v
release SDA
    |
    v
generate recovery clock 1
    |
    v
observe SDA while SCL HIGH
    |
    v
record first SDA release if observed
    |
    v
continue recovery clocks
    |
    v
complete recovery clock 9
    |
    +---- SDA HIGH ----> WAIT_BUS_FREE -> WAIT_TBUF -> success
    |
    +---- SDA LOW -----> recovery failure

### F1 Recovery Success

Recovery success requires more than merely observing SDA HIGH once.

After SDA is released:

1. recovery pulse generation stops;
2. the controller releases SDA and SCL;
3. the bus must satisfy the valid free-bus condition;
4. the required bus-free interval must be respected;
5. the controller returns to IDLE.

Only then is recovery considered complete.

### F1 Recovery Failure

If SDA remains LOW after the maximum recovery attempt:

```text
recovery_failed = 1
```

The controller must:

- stop generating recovery pulses;
- release SDA;
- release SCL;
- leave fault status visible;
- avoid starting a new transaction automatically.

The testbench may later clear/reset the controller according to the frozen
verification policy.

---

### F2 Containment Sequence

The controller cannot force SCL HIGH when another open-drain device
physically holds SCL LOW.

Therefore F2 uses containment instead of an active bus-clear sequence.

Conceptually:

```text
F2 detected
    |
    v
terminate / contain current transaction
    |
    v
release SDA
release SCL
    |
    v
fault status remains active
    |
    v
WAIT_SCL_RELEASE
    |
    +---- SCL LOW ----> remain contained
    |
    +---- SCL HIGH
              |
              v
       WAIT_BUS_FREE
              |
              +---- SDA/SCL not free -> wait
              |
              +---- bus free
                        |
                        v
                    wait tBUF
                        |
                        v
                      IDLE
```

### F2 Return to Service

The controller may return to normal service only after:

- the external SCL-holding condition disappears;
- SCL is HIGH;
- SDA is HIGH;
- the bus-free requirement is satisfied;
- the required `tBUF` interval has elapsed.

The exact behavior of `fault_active` after return to service will be frozen
during S3.4/S4.

---

## Fault Status Interface

The fault-aware version adds status outputs to the baseline interface.

Recommended initial interface:

```systemverilog
output logic       fault_active;
output logic [1:0] fault_code;
output logic       recovery_active;
output logic       recovery_failed;
```

### `fault_active`

Indicates that a supported abnormal condition has been detected and has not
yet been cleared according to the final status policy.

### `fault_code`

Identifies the detected condition.

Recommended encoding:

```text
00 -> NONE
01 -> SDA_STUCK
10 -> SCL_STALL
11 -> RESERVED / future use
```

### `recovery_active`

Indicates active F1 bus-clear recovery or F2 containment handling.

### `recovery_failed`

Indicates that the supported automatic F1 recovery procedure did not clear
the SDA-stuck condition.

The exact persistence/clearing behavior of these status outputs will be
frozen during the recovery-FSM stage.

---

## Parameter Set

The fault-aware design retains all baseline timing parameters.

Baseline parameters include conceptually:

```systemverilog
parameter integer SYS_CLK_HZ = 100_000_000;
parameter integer I2C_CLK_HZ = 100_000;
```

The fault-aware extension adds:

```systemverilog
parameter integer SDA_STUCK_LIMIT_CYCLES = ...;
parameter integer SCL_STALL_LIMIT_CYCLES = ...;
```

Additional implementation-derived counter widths may use local parameters.

The exact numerical values of:

```text
SDA_STUCK_LIMIT_CYCLES
SCL_STALL_LIMIT_CYCLES
```

are not frozen in this document.

They must be selected during S3.4/S4 so that:

- the behavior is reproducible;
- test boundary conditions are precisely defined;
- legal protocol activity is not falsely classified;
- simulation runtime remains practical;
- hardware behavior remains realistic.

The eventual implementation should permit the thresholds to be modified
through RTL parameters rather than requiring logic redesign.

---

## Matched-Comparison Rule

The proposed design must remain matched with the baseline.

The comparison must use:

```text
same host interface
same transaction FSM
same bit/timing engine
same open-drain implementation
same protocol features
same Standard-mode configuration
same FPGA target
same Vivado version
same clock constraint
same synthesis strategy
same implementation strategy
```

The only intentional architectural additions should be related to:

```text
F1/F2 monitoring
fault counters
classification
recovery/containment
fault status
measurement support
```

The final PPA comparison will therefore evaluate:

```text
Baseline controller
        versus
Baseline controller + fault-management extension
```

Candidate FPGA metrics include:

- LUT;
- FF;
- critical timing;
- Fmax;
- percentage LUT overhead;
- percentage FF overhead;
- normal-operation latency impact;
- power only if reproducibly measurable.

---

## Measurement Hooks

The architecture must support automated measurement of fault-handling
behavior.

The testbench should be able to determine the following events:

```text
fault stimulus begins
fault condition becomes detectable
fault indication asserts
recovery/containment begins
recovery/containment completes
post-recovery transaction begins
post-recovery transaction completes
```

### Detection Latency

Detection latency is provisionally defined as:

```text
fault detection timestamp
-
defined fault-onset timestamp
```

The exact onset definition is fault-specific and will be frozen in the
verification plan.

### Recovery Latency

For F1:

```text
recovery-complete timestamp
-
fault-detection timestamp
```

For F2:

```text
containment / return-to-service timestamp
-
fault-detection timestamp
```

The exact recovery-complete criterion must remain consistent between RTL,
testbench, results, and paper.

### Recovery Pulse Count

For F1, the testbench must record how many SCL recovery pulses were required
before SDA was released.

Required cases include release after:

- pulse 1;
- pulse 3;
- pulse 5;
- pulse 9;
- never release.

### Threshold Boundary Measurement

For F2, the testbench must exercise at least:

```text
well below threshold
threshold - 1
threshold boundary
threshold + 1
indefinite SCL LOW
SCL released after fault detection
```

The exact boundary convention must be frozen before RTL verification
closure.

---

## Safety / Protocol Rules

The fault-aware extension must obey the following rules.

### Rule 1 — Normal behavior must remain unchanged

When no supported fault exists, the proposed controller must behave like the
baseline controller.

### Rule 2 — No false F1 during normal SDA LOW

SDA LOW during legal protocol activity must not trigger F1.

### Rule 3 — No F2 during controller-driven SCL LOW

The controller's own intentional LOW clock phase must never count toward the
F2 threshold.

### Rule 4 — Legal clock stretching below threshold is accepted

The proposed controller must continue the transaction normally when SCL is
released before `SCL_STALL_LIMIT_CYCLES` is reached.

### Rule 5 — F2 must not force SCL HIGH

If an external device holds SCL LOW, the controller must release the line and
wait rather than drive an illegal push-pull HIGH.

### Rule 6 — F1 recovery generates nine recovery clocks

The normal F1 bus-clear sequence generates exactly nine completed recovery
clocks.

The controller records the first recovery pulse on which SDA is observed
released HIGH, but SDA release before the ninth recovery clock does not
normally terminate the sequence.

If SCL itself remains LOW for `SCL_STALL_LIMIT_CYCLES` while F1 recovery is
waiting for SCL HIGH, F2 preempts the F1 sequence.

In that case, F1 recovery is abandoned and the controller sequentially
reclassifies the active condition as `FAULT_SCL_STALL` and enters F2
containment.

### Rule 7 — Recovery must not automatically imply success

Successful recovery requires a valid bus condition and completion of the
defined bus-free requirement.

### Rule 8 — Failed recovery must be visible

If F1 recovery fails, the controller must report the failure and avoid
silently returning to normal operation.

### Rule 9 — Post-recovery operation must be verified

After successful recovery/return to service, a subsequent normal I2C
transaction must be checked automatically.

### Rule 10 — Scope must remain fixed

Additional fault classes must not be added merely because implementation
makes them convenient.

Any scope change requires reopening the S2/S3 research decision.

---

## S3.3 Exit Criteria

S3.3 passes only when all of the following are satisfied:

```text
[ ] Baseline/proposed architectural sharing is explicit.
[ ] Added hardware blocks are clearly defined.
[ ] F1 detection context is unambiguous.
[ ] F2 detection context is unambiguous.
[ ] F1 recovery behavior is defined.
[ ] F1 failure behavior is defined.
[ ] F2 containment behavior is defined.
[ ] F2 return-to-service behavior is defined.
[ ] Fault-classification priority is defined.
[ ] Fault/status outputs are defined.
[ ] Thresholds are parameterized.
[ ] Measurement hooks are identified.
[ ] False-positive protections are explicit.
[ ] Open-drain safety rules are preserved.
[ ] No additional primary fault class has been introduced.
[ ] Matched FPGA comparison remains valid.
```

After S3.3 passes, the next stage is S3.4.

S3.4 will freeze:

- the exact F1 recovery FSM;
- the exact F2 containment FSM;
- fault-status clearing behavior;
- parameter boundary semantics;
- recovery-complete definitions;
- interaction between the fault controller and baseline transaction FSM.

The architecture is not ready for RTL until S3.4 and the final S3 consistency
review both pass.