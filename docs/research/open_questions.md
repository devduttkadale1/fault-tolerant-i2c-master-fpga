# Open Research and Design Questions

The broad literature questions are now closed sufficiently for provisional scope selection.

The remaining questions are primarily S3 architecture and S4 verification questions.

## F1 — SDA Stuck LOW

- Under exactly which controller/bus states is SDA allowed to be classified as stuck LOW?
- How long must SDA remain LOW before detection?
- When should autonomous bus clear be initiated?
- What exact event defines successful recovery?
- What status is reported when SDA does not release within nine recovery clocks?
- How is a post-recovery transaction started safely?

## F2 — Prolonged SCL LOW

- What configurable threshold will define project-specific loss of progress?
- In which FSM states should the SCL-low timer operate?
- How will legal clock stretching below the threshold be verified?
- What happens exactly when the threshold expires?
- How does the controller behave while another device continues to hold SCL LOW?
- What event permits the controller to return to service?

## Baseline / Architecture

- What is the minimum baseline command/status interface required for reproducible experiments?
- What FPGA system-clock frequency will be used?
- What counter widths and timing-divider values are required?
- Which logic is shared between baseline and proposed designs to ensure a matched PPA comparison?

## Verification

- Which assertions are required for normal protocol behavior?
- Which assertions directly check fault detection and recovery behavior?
- What functional coverage and fault-scenario coverage will be collected?
- How will detection latency and recovery latency be measured automatically?
- What exact PASS/FAIL condition defines post-recovery correctness?
- What randomization, if any, requires reproducible seeds?

## Experimental Evaluation

- How many deterministic and randomized fault scenarios are required?
- Which SDA-release pulse positions will be tested?
- Which SCL-stretch durations around the threshold will be tested?
- Which FPGA device and clock constraint will be frozen for baseline-versus-proposed comparison?
- Is power estimation sufficiently reproducible to report, or should it remain optional?

## Scope Control

- F1 SDA stuck LOW and F2 prolonged SCL LOW are the provisional primary conditions.
- ACK/NACK retry exhaustion is not currently a primary research condition.
- UVM, multi-controller arbitration, and additional unrelated fault classes are outside the initial 15-day implementation scope.
