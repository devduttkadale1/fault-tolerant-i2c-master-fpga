# Fault Model

## Status

This fault model is provisional after S2 and will be frozen at S3 closure.

The project supports two primary abnormal bus conditions only.

## F1 — SDA Stuck LOW

### Detection context

F1 detection is enabled only when the controller expects the bus to be free.

SDA LOW during normal address, data, ACK, or START activity must not be classified as F1.

### Detection condition

F1 is asserted when SCL is observed HIGH while SDA remains LOW continuously for SDA_STUCK_LIMIT_CYCLES during a controller state that expects a free bus.

### Recovery action

The controller releases SDA and performs an autonomous bus-clear attempt
using exactly nine SCL recovery pulses.

SDA is observed while SCL is HIGH during each recovery clock.

The controller records the first recovery pulse on which SDA is observed
released HIGH, but the recovery sequence normally continues until all nine
recovery clocks have completed.

After the ninth completed recovery clock:

- if SDA is HIGH, the controller proceeds to bus-free and `tBUF`
  qualification before returning to service;
- if SDA remains LOW, autonomous F1 recovery is considered failed.

If SCL remains LOW for `SCL_STALL_LIMIT_CYCLES` while the controller is
attempting an F1 recovery clock, F1 recovery is abandoned.

The active condition is then sequentially reclassified as F2
`SCL_STALL`, and control transfers to F2 containment.

Only one primary fault classification is active at a time.

SDA is observed during each recovery clock while SCL is HIGH.

The controller records the first recovery pulse on which SDA is observed
released HIGH, but the recovery-clock sequence continues until all nine
recovery clocks have completed.

### Recovery success

After nine recovery clocks have completed, recovery may proceed only if SDA
is observed HIGH.

The controller then releases SDA and SCL, waits for the bus to satisfy the
free-bus condition continuously for the required `tBUF` interval, and
returns to IDLE.

### Recovery failure

If SDA remains LOW after all nine recovery clocks have completed, the
controller releases its bus drives and reports recovery failure.

### SCL stall during F1 recovery

F1 recovery requires the controller to release SCL during every recovery
clock.

If actual SCL remains LOW for `SCL_STALL_LIMIT_CYCLES` while F1 recovery is
waiting for SCL HIGH, the F1 bus-clear sequence is abandoned.

The active classification changes sequentially to F2 `SCL_STALL`, and
control transfers to F2 containment.

Only one fault code is active at a time.

## F2 — Prolonged SCL LOW

### Detection context

F2 monitoring is active only when the controller has released SCL and expects the actual bus SCL level to become HIGH.

The controller's intentional SCL LOW phase

### Detection condition

F2 is asserted when actual SCL remains LOW for at least SCL_STALL_LIMIT_CYCLES while the controller is waiting for SCL HIGH.

Stretch durations below the configured threshold remain legal supported behavior.

### Containment action

On F2 detection, the current transaction is aborted, SDA and SCL are released, and the controller enters a fault-wait state.

The controller does not attempt to force SCL HIGH because another open-drain device may be physically holding it LOW.

### Return to service

The controller may return to IDLE only after the externally held condition disappears and the bus satisfies the free-bus requirement.

## Fault Classification Priority

If SCL is expected HIGH but remains LOW, F2 classification takes priority.

F1 requires SCL HIGH together with SDA LOW while the bus is expected to be free.

## Explicitly Outside the Primary Fault Model

- NACK by itself
- arbitration loss
- reset during transfer
- noise and glitches
- multi-controller conflicts
- Fast-mode timing faults
- generic internal FPGA faults

## Required Experimental Measurements

- detection success
- missed detection
- false detection
- recovery or containment success
- detection latency
- recovery or containment latency
- post-recovery transaction correctness
- baseline-versus-proposed FPGA overhead
