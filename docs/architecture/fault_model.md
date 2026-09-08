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

The controller releases SDA and attempts autonomous bus clear using at most nine SCL recovery pulses.

SDA is checked during the recovery sequence.

### Recovery success

Recovery succeeds when SDA is observed released HIGH and the bus can subsequently satisfy the free-bus condition.

The controller then waits the required bus-free interval before returning to IDLE.

### Recovery failure

If SDA does not release within nine recovery clocks, the controller releases its bus drives and reports recovery failure.

## F2 — Prolonged SCL LOW

### Detection context

F2 monitoring is active only when the controller has released SCL and expects the actual bus SCL level to become HIGH.

The controllers intentional SCL LOW phase is not counted as F2.

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
