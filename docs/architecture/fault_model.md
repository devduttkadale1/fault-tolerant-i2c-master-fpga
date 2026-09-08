# Fault Model

## Status

This fault model is frozen at S3 architecture closure.

The project supports two primary abnormal bus conditions only.

## F1 — SDA Stuck LOW

### Detection context

F1 detection is enabled only when the controller expects the bus to be free.

SDA LOW during normal address, data, ACK, or START activity must not be
classified as F1.

### Detection condition

F1 is asserted when SCL is observed HIGH while SDA remains LOW continuously
for `SDA_STUCK_LIMIT_CYCLES` during a controller state that expects a free
bus.

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

### Recovery success

Recovery is successful only when:

- all nine recovery clocks have completed;
- SDA is HIGH;
- SCL is HIGH;
- the bus remains free for the required `tBUF` interval.

The controller may then return to normal service.

### Recovery failure

If SDA remains LOW after all nine recovery clocks have completed, the
controller releases SDA and SCL and reports recovery failure.

The failed condition remains visible according to the recovery-status policy.

### SCL stall during F1 recovery

F1 recovery requires SCL to be released during every recovery clock.

If actual SCL remains LOW for `SCL_STALL_LIMIT_CYCLES` while F1 recovery is
waiting for SCL HIGH, the F1 bus-clear sequence is abandoned.

The active condition is sequentially reclassified as F2 `SCL_STALL`, and
control transfers to F2 containment.

Only one primary fault classification is active at a time.

---

## F2 — Prolonged SCL LOW

### Detection context

F2 monitoring is active only when the controller has released SCL and
expects the actual bus SCL level to become HIGH.

The controller's intentional SCL LOW phase is not counted toward F2.

### Detection condition

F2 is asserted when actual SCL remains LOW for at least
`SCL_STALL_LIMIT_CYCLES` while the controller is waiting for SCL HIGH.

Stretch durations below the configured threshold remain legal supported
behavior.

The threshold is an implementation-defined loss-of-progress policy and is
not a mandatory base-I2C timeout requirement.

### Containment action

On F2 detection, the current transaction is terminated, SDA and SCL are
released, and the controller enters a contained fault-wait state.

The controller does not attempt to force SCL HIGH because another open-drain
device may be physically holding it LOW.

### Return to service

The controller may return to IDLE only after:

- the externally held SCL condition disappears;
- SCL is HIGH;
- SDA is HIGH;
- the bus remains free for the required `tBUF` interval.

The interrupted transaction is not automatically resumed or retried.

---

## Fault Classification Priority

If SCL is expected HIGH but remains LOW, F2 classification takes priority.

F1 requires SCL HIGH together with SDA LOW while the controller expects the
bus to be free.

If F2 occurs during an active F1 recovery attempt, the condition is
sequentially reclassified from F1 to F2 rather than reporting both faults
simultaneously.

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
