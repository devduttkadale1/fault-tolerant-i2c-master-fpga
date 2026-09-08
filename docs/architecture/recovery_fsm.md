# Recovery and Containment FSM

## Purpose

This document freezes the controller-level handling behavior for the two
primary abnormal bus conditions selected by the project:

- F1 — SDA stuck LOW;
- F2 — prolonged SCL LOW.

The purpose is to remove ambiguity before the verification plan and RTL
implementation begin.

The fault-aware controller uses the same normal I2C protocol engine as the
baseline controller.

The recovery controller intervenes only after one of the supported
conditions has been detected.

---

## General Design Rules

The recovery logic must satisfy the following rules.

1. Normal fault-free I2C behavior must remain identical to the baseline.
2. F1 and F2 must not be asserted from bus levels without protocol context.
3. F1 and F2 must not be active simultaneously.
4. F2 takes classification priority when the controller expects SCL HIGH
   but actual SCL remains LOW.
5. The controller must preserve open-drain operation.
6. The controller must never actively drive SDA or SCL HIGH.
7. Fault handling must prevent acceptance of a new host command while
   recovery or containment is active.
8. Failed recovery must remain visible to the host/testbench.
9. A successful recovery must be followed by verification that the bus is
   free before normal operation resumes.

---

## Fault Codes

Recommended encoding:

```systemverilog
typedef enum logic [1:0] {
    FAULT_NONE      = 2'b00,
    FAULT_SDA_STUCK = 2'b01,
    FAULT_SCL_STALL = 2'b10,
    FAULT_RESERVED  = 2'b11
} fault_code_t;
```

The exact SystemVerilog declaration may be adjusted during RTL
implementation, but the functional meaning must remain unchanged.

---

## Detection Counter Semantics

To avoid off-by-one ambiguity, both fault thresholds use the same rule.

A fault is detected after the qualifying condition has been observed for
exactly the configured number of consecutive system-clock samples.

Therefore:

```text
LIMIT = N
```

means:

```text
qualifying samples 1 through N-1 -> no fault
qualifying sample N             -> fault detected
```

If the qualifying condition disappears before sample N, the corresponding
counter resets to zero.

This convention must be used consistently by:

- RTL;
- assertions;
- testbench;
- latency measurement;
- threshold-boundary tests;
- results reported in the paper.

---

# F1 — SDA Stuck LOW

## F1 Detection Context

F1 monitoring is enabled only when the controller expects a free bus.

Conceptually:

```text
expect_bus_free = 1
AND
scl_in = HIGH
AND
sda_in = LOW
```

The condition must persist for:

```text
SDA_STUCK_LIMIT_CYCLES
```

before F1 is asserted.

SDA LOW during active address, data, ACK, or START phases must not count
toward this threshold.

---

## F1 Recovery FSM

Recommended states:

```text
F1_IDLE
F1_DETECTED
F1_PREPARE
F1_PULSE_LOW
F1_RELEASE_SCL
F1_WAIT_SCL_HIGH
F1_CHECK_SDA
F1_WAIT_BUS_FREE
F1_WAIT_TBUF
F1_SUCCESS
F1_FAILED
```

---

## F1_IDLE

Normal fault-management idle state.

No recovery is active.

On valid F1 detection:

```text
fault_active = 1
fault_code = FAULT_SDA_STUCK
```

and transition to:

```text
F1_DETECTED
```

---

## F1_DETECTED

The controller prevents acceptance of new commands.

The recovery controller takes control of the bus interface.

Transition to:

```text
F1_PREPARE
```

---

## F1_PREPARE

Actions:

```text
release SDA
initialize recovery pulse counter to zero
set recovery_active
```

Then transition to:

```text
F1_PULSE_LOW
```

---

## F1_PULSE_LOW

The recovery controller actively pulls SCL LOW for the configured
recovery-clock LOW period.

SDA remains released.

After the LOW timing requirement is satisfied:

```text
F1_RELEASE_SCL
```

---

## F1_RELEASE_SCL

The controller releases SCL.

Because the interface is open-drain, releasing SCL does not guarantee that
the physical bus becomes HIGH.

Transition to:

```text
F1_WAIT_SCL_HIGH
```

---

## F1_WAIT_SCL_HIGH

The controller observes actual:

```text
scl_in
```

If SCL remains LOW, the controller waits.

The controller must not force SCL HIGH.

When SCL is observed HIGH, the HIGH portion of the recovery clock is
completed and the pulse counter is incremented.

Then transition to:

```text
F1_CHECK_SDA
```

---

## F1_CHECK_SDA

The controller observes actual SDA while SCL is HIGH.

If SDA is observed HIGH for the first time, the controller records the
current recovery-pulse number as the SDA release point.

The recovery clock sequence nevertheless continues until nine complete
recovery clocks have been generated.

If nine recovery clocks complete and SDA is HIGH:

F1_WAIT_BUS_FREE

If nine recovery clocks complete and SDA remains LOW:

F1_FAILED

The experiment records the first recovery pulse on which SDA was observed
released.

This permits recovery-effectiveness measurement while keeping the bus-clear
sequence directly aligned with the nine-clock recommendation used by this
project.

## F1_WAIT_BUS_FREE

Both controller outputs remain released.

The controller waits until:

```text
sda_in = HIGH
AND
scl_in = HIGH
```

Once the free-bus electrical state exists, transition to:

```text
F1_WAIT_TBUF
```

---

## F1_WAIT_TBUF

The bus must remain free continuously for the configured Standard-mode
`tBUF` interval.

If either SDA or SCL becomes LOW before `tBUF` completes:

```text
reset tBUF counter
return to F1_WAIT_BUS_FREE
```

When `tBUF` completes:

```text
F1_SUCCESS
```

---

## F1_SUCCESS

Recovery is considered successful only at this point.

Actions:

```text
recovery_active = 0
recovery_failed = 0
```

The controller returns to normal IDLE/service.

The previous F1 fault code may remain latched temporarily according to the
status-clearing policy defined later in this document.

A subsequent normal transaction must be accepted and verified by the
testbench.

---

## F1_FAILED

This state is entered when SDA remains LOW following nine completed
recovery clocks.

Actions:

```text
release SDA
release SCL
fault_active = 1
fault_code = FAULT_SDA_STUCK
recovery_active = 0
recovery_failed = 1
cmd_ready = 0
```

The controller must not silently resume normal transactions.

The initial project policy is:

```text
F1_FAILED remains latched until reset.
```

External hardware reset or system-level recovery is outside the autonomous
controller scope.

---

## SCL Stall During F1 Recovery

F1 bus-clear recovery still uses open-drain SCL.

Therefore, when the recovery controller releases SCL during
`F1_WAIT_SCL_HIGH`, an external device may continue holding SCL LOW.

The F2 loss-of-progress threshold remains applicable during this wait.

If actual SCL remains LOW for `SCL_STALL_LIMIT_CYCLES` during an F1
recovery clock:

1. F1 pulse generation is abandoned;
2. the controller releases SDA and SCL;
3. the active classification changes to `FAULT_SCL_STALL`;
4. recovery control transfers to F2 containment;
5. no attempt is made to force SCL HIGH.

This is a sequential reclassification rather than simultaneous F1/F2
assertion.

The controller supports only one active fault code at a time, and SCL-stall
classification has priority because bus-clear clock generation cannot
continue while SCL is externally held LOW.

# F2 — Prolonged SCL LOW

## F2 Detection Context

F2 monitoring is enabled only when:

```text
waiting_for_scl_high = 1
AND
scl_drive_low = 0
AND
scl_in = LOW
```

This means the controller has released SCL and expects it to become HIGH.

The controller's intentional SCL LOW phase is excluded.

The condition must persist for:

```text
SCL_STALL_LIMIT_CYCLES
```

before F2 is asserted.

---

## F2 Containment FSM

Recommended states:

```text
F2_IDLE
F2_DETECTED
F2_RELEASE_BUS
F2_WAIT_SCL_RELEASE
F2_WAIT_BUS_FREE
F2_WAIT_TBUF
F2_SUCCESS
```

There is no autonomous SCL-forcing recovery state.

---

## F2_IDLE

Normal fault-management idle state.

On valid F2 detection:

```text
fault_active = 1
fault_code = FAULT_SCL_STALL
```

Transition to:

```text
F2_DETECTED
```

---

## F2_DETECTED

The active transaction is marked as fault-terminated.

No additional normal protocol bit operations are started.

New commands are blocked.

Transition to:

```text
F2_RELEASE_BUS
```

---

## F2_RELEASE_BUS

The controller releases both open-drain outputs:

```text
sda_drive_low = 0
scl_drive_low = 0
```

Set:

```text
recovery_active = 1
```

No attempt is made to generate an SCL HIGH level actively.

Transition to:

```text
F2_WAIT_SCL_RELEASE
```

---

## F2_WAIT_SCL_RELEASE

If:

```text
scl_in = LOW
```

the controller remains contained.

If:

```text
scl_in = HIGH
```

transition to:

```text
F2_WAIT_BUS_FREE
```

---

## F2_WAIT_BUS_FREE

The controller waits until:

```text
scl_in = HIGH
AND
sda_in = HIGH
```

If the complete free-bus condition is observed:

```text
F2_WAIT_TBUF
```

---

## F2_WAIT_TBUF

The bus must remain continuously free for the configured `tBUF`.

If SDA or SCL returns LOW before `tBUF` completes:

```text
reset tBUF counter
return to F2_WAIT_BUS_FREE
```

When `tBUF` completes:

```text
F2_SUCCESS
```

---

## F2_SUCCESS

The controller has successfully contained the stalled transaction and the
external SCL-holding condition has disappeared.

Actions:

```text
recovery_active = 0
```

The controller returns to normal IDLE/service.

The original transaction is not automatically retried.

A new transaction must be issued explicitly by the host/testbench.

A post-containment transaction must later be verified automatically.

---

# Fault Status Clearing Policy

The initial status policy is designed so that fault information remains
observable after successful handling.

## Successful F1 or F2 Handling

After successful recovery/containment:

```text
fault_active remains asserted
fault_code remains latched
recovery_active becomes 0
recovery_failed remains 0
```

The controller may return to `cmd_ready = 1`.

When the next command is successfully accepted:

```text
cmd_valid && cmd_ready
```

the previous successful fault indication is cleared:

```text
fault_active = 0
fault_code = FAULT_NONE
```

This allows software/testbench logic to observe the previous fault before
starting the next transaction.

---

## Failed F1 Recovery

For:

```text
F1_FAILED
```

the following remain latched:

```text
fault_active = 1
fault_code = FAULT_SDA_STUCK
recovery_failed = 1
cmd_ready = 0
```

They are cleared only by reset.

---

# Busy and Done Semantics

## Normal Transaction

During an accepted normal command:

```text
busy = 1
```

until transaction completion.

`done` generates a completion pulse when the normal transaction completes.

---

## F2 During Active Transaction

When F2 terminates an active transaction:

```text
busy remains asserted
```

through containment.

When F2 containment completes and the controller returns to service:

```text
busy = 0
done = 1 for one system-clock cycle
```

The latched `fault_code` indicates that the completed command did not finish
normally.

---

## F1 Without an Active Command

F1 may occur while the controller is waiting for a free bus before accepting
a new transaction.

In this case autonomous recovery does not create a false command completion.

Therefore:

```text
done is not asserted merely because autonomous F1 recovery completes
```

The controller simply returns to command-ready state after successful
recovery.

---

# Command Acceptance During Fault Handling

The controller must deassert:

```text
cmd_ready
```

during:

- F1 recovery;
- F2 containment;
- F1 failed recovery.

After successful F1/F2 handling and completion of `tBUF`, command acceptance
may resume.

No new command may interrupt an active recovery sequence.

---

# Recovery Clock Timing

F1 recovery pulses must use controlled LOW and HIGH intervals consistent
with the selected Standard-mode timing strategy.

The recovery clock generator should reuse the existing baseline timing
infrastructure wherever practical.

This avoids creating an unrelated second clock-generation architecture and
helps preserve a fair PPA comparison.

---

# Fault Detector Reset Rules

The F1 detection counter resets whenever any F1 qualifying condition becomes
false.

The F2 detection counter resets whenever any F2 qualifying condition becomes
false.

Both detector counters are reset:

- by `rst_n`;
- when the controller enters the corresponding fault-handling FSM;
- before returning to normal monitoring after successful handling.

---

# Required Boundary Tests

## F1

Required deterministic cases:

```text
SDA releases on recovery pulse 1
SDA releases on recovery pulse 3
SDA releases on recovery pulse 5
SDA releases on recovery pulse 9
SDA never releases
```

Expected results:

```text
pulses 1/3/5/9 -> recovery success
never release  -> F1_FAILED
```

---

## F2

Required deterministic threshold cases:

```text
SCL LOW for significantly less than LIMIT
SCL LOW for LIMIT - 1 qualifying samples
SCL LOW for exactly LIMIT qualifying samples
SCL LOW for LIMIT + 1 samples
SCL LOW indefinitely
SCL released after F2 detection
```

Using the frozen threshold convention:

```text
LIMIT - 1 -> no F2
LIMIT     -> F2 asserted
LIMIT + 1 -> F2 remains asserted/contained
```

This rule must be checked automatically by the future testbench.

---

# Recovery Completion Definitions

## F1 Recovery Completion

F1 recovery is complete when:

```text
SDA = HIGH
AND
SCL = HIGH
AND
the required tBUF interval has completed
```

after successful bus-clear operation.

---

## F2 Containment Completion

F2 handling is complete when:

```text
external SCL hold has disappeared
AND
SDA = HIGH
AND
SCL = HIGH
AND
the required tBUF interval has completed
```

The original interrupted transaction is considered failed and is not resumed
from its previous protocol state.

---

# Interaction With Baseline Transaction FSM

The fault-management controller may override the normal transaction FSM only
during supported F1/F2 handling.

Conceptually:

```text
normal operation
    |
baseline FSM controls SDA/SCL
    |
fault detected
    |
recovery controller gains bus-control ownership
    |
recovery/containment completes
    |
baseline FSM reset/returned to IDLE
    |
normal control ownership restored
```

A simple conceptual ownership signal may later be implemented:

```text
recovery_owns_bus
```

When:

```text
recovery_owns_bus = 0
```

the baseline bit/timing engine controls SDA/SCL.

When:

```text
recovery_owns_bus = 1
```

the recovery controller controls SDA/SCL.

The final RTL implementation may use multiplexed control signals rather than
this exact signal name.

---

# S3.4 Exit Criteria

S3.4 passes only when all of the following are unambiguous:

```text
[ ] F1 detector threshold semantics are defined.
[ ] F2 detector threshold semantics are defined.
[ ] F1 recovery states are defined.
[ ] Nine-pulse maximum behavior is defined.
[ ] F1 success criterion is defined.
[ ] F1 failure criterion is defined.
[ ] F2 containment states are defined.
[ ] F2 return-to-service criterion is defined.
[ ] Fault status clearing behavior is defined.
[ ] recovery_failed persistence is defined.
[ ] cmd_ready behavior during recovery is defined.
[ ] busy/done behavior is defined.
[ ] Post-fault transaction behavior is defined.
[ ] Recovery clock ownership is defined.
[ ] tBUF behavior after recovery is defined.
[ ] Threshold boundary tests are defined.
[ ] No automatic retry is introduced.
[ ] Open-drain behavior remains preserved.
```

After S3.4 passes, a final S3 architecture consistency audit must confirm
that:

```text
fault_model.md
baseline_architecture.md
fault_aware_architecture.md
recovery_fsm.md
project_target.md
```

all describe the same system.

Only then may S3 close and S4 verification planning begin.