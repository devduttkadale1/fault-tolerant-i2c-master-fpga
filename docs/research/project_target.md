# Project Research Target

## 1. Project Objective

This project investigates a fault-aware FPGA-based I2C master
controller designed to detect and handle a small, explicitly defined
set of abnormal I2C bus conditions.

The project uses a conventional FPGA I2C master as a matched baseline
and evaluates the incremental behavior and implementation cost of the
fault-management extension.

The primary objective is not simply to implement another I2C master.

The research objective is to determine whether selected abnormal bus
conditions can be detected and handled in hardware while:

- preserving legal I2C behavior;
- avoiding false fault classification;
- providing measurable recovery or containment behavior;
- maintaining correct post-recovery communication; and
- introducing acceptable FPGA implementation overhead.

---

## 2. Problem Statement

Conventional FPGA I2C masters primarily implement nominal protocol
communication.

Abnormal bus conditions can prevent transaction progress or leave a
controller unable to continue communication.

Two particularly relevant conditions for this project are:

1. SDA remaining LOW when the controller expects a free bus.
2. SCL remaining LOW after the controller has released SCL and expects
   the line to become HIGH.

The engineering problem is not merely detecting a LOW signal.

The controller must distinguish abnormal conditions from legal I2C
behavior.

Examples include:

- SDA LOW during normal address/data transmission;
- SDA LOW during ACK;
- legal clock stretching;
- the controller's own intentional SCL LOW phase.

Therefore the project investigates context-aware hardware detection,
recovery/containment, and quantitative evaluation rather than simple
signal-level timeout logic.

---

## 3. Candidate Research Gap

Within the reviewed Category A, B, and D evidence, no explicit evidence
was identified for the complete combination of:

- matched conventional-versus-fault-aware FPGA I2C masters;
- autonomous SDA-stuck-LOW detection;
- controlled SDA bus-clear recovery;
- configurable prolonged-SCL-LOW loss-of-progress detection;
- discrimination from legal clock stretching;
- deliberate SystemVerilog abnormal-bus fault injection;
- false-detection analysis;
- detection-latency measurement;
- recovery/containment-latency measurement;
- post-recovery transaction validation; and
- incremental FPGA implementation-cost measurement.

This is a candidate research gap within the reviewed evidence.

It is not a literature-wide absence claim and is not currently a
novelty claim.

---

## 4. Proposed Solution

The experimental system contains two matched designs.

### 4.1 Baseline Controller

The baseline is a conventional FPGA I2C master supporting the protocol
features required by the experiment.

Initial target:

- Standard-mode I2C;
- nominal 100 kHz SCL;
- 7-bit addressing;
- single-controller operation;
- START;
- STOP;
- repeated START if retained by final architecture;
- byte write;
- byte read;
- ACK/NACK;
- open-drain SDA/SCL behavior;
- legal clock-stretch observation.

The baseline does not contain the proposed fault-management extension.

### 4.2 Fault-Aware Controller

The proposed design uses the same protocol engine and adds only the
hardware required for the supported fault-management functions.

Conceptual extension:

Bus Monitor
→ Fault Detector
→ Fault Classifier
→ Recovery / Containment Controller
→ Fault and Recovery Status

Primary conditions:

- F1: SDA stuck LOW.
- F2: prolonged SCL LOW.

---

## 5. Primary Fault F1 — SDA Stuck LOW

### Detection

F1 monitoring is enabled only when the controller expects the bus to
be free.

The candidate detection condition is:

- SCL observed HIGH;
- SDA observed LOW;
- controller expects a free bus;
- condition persists for SDA_STUCK_LIMIT_CYCLES.

Normal SDA LOW periods must not trigger F1.

### Recovery

The controller:

1. releases SDA;
2. generates controlled SCL recovery clocks;
3. observes SDA while SCL is HIGH;
4. records the first recovery pulse on which SDA is released;
5. completes exactly nine recovery clocks unless F2 preempts the sequence
   because SCL itself becomes stalled;
6. checks SDA after the ninth completed recovery clock;
7. waits for the required free-bus interval following successful recovery;
8. returns to IDLE after successful recovery.

If SDA remains LOW after nine completed recovery clocks, autonomous F1
recovery is considered unsuccessful.

### F1-to-F2 Reclassification

If SCL remains LOW for `SCL_STALL_LIMIT_CYCLES` while the controller is
attempting an F1 recovery clock, the bus-clear sequence cannot continue.

The controller therefore abandons F1 recovery, sequentially reclassifies
the active condition as F2 `SCL_STALL`, releases the bus, and enters F2
containment.

### Failure

If SDA remains LOW following the permitted recovery attempt, the
controller releases its bus outputs and reports recovery failure.

---

## 6. Primary Fault F2 — Prolonged SCL LOW

Base I2C permits clock stretching and does not define the project's
future timeout threshold.

Therefore F2 is an implementation-defined loss-of-progress condition,
not an I2C protocol violation.

### Detection

F2 monitoring is enabled only when:

- the controller has released SCL; and
- the controller expects actual SCL to become HIGH.

The controller's own intentional SCL LOW phase is excluded.

SCL remaining LOW for less than the configured threshold is treated as
legal supported clock stretching.

SCL remaining LOW for at least SCL_STALL_LIMIT_CYCLES is classified as
F2.

### Containment

When F2 is detected:

1. the current transaction is terminated or contained safely;
2. SDA and SCL are released;
3. fault status is asserted;
4. the controller waits for the external SCL-holding condition to
   disappear;
5. the controller waits for a valid free bus;
6. the controller returns to service.

The FPGA does not attempt to force externally held SCL HIGH.

---

## 7. Primary Experimental Questions

### WRQ1 — Detection and Discrimination

Can the controller detect F1 and F2 without falsely classifying legal
I2C behavior?

### WRQ2 — SDA Recovery

How effectively does controlled bus-clear recover the bus under
different SDA-release scenarios?

### WRQ3 — SCL-Stall Containment

Can prolonged SCL LOW be detected and contained safely while still
supporting legal clock stretching below the configured threshold?

### WRQ4 — Latency and Correctness

What are the detection latency, recovery/containment latency, and
post-recovery transaction-success characteristics?

### WRQ5 — FPGA Cost

What incremental FPGA resource and timing overhead does the
fault-management extension introduce relative to the matched baseline?

These RQs are provisionally frozen after S2 and will be finalized only
after S3/S4 validation.

---

## 8. Required Measurements

### F1

- detection success;
- missed detections;
- detection latency;
- recovery success;
- recovery pulse count;
- recovery latency;
- recovery failure;
- post-recovery transaction correctness.

### F2

- detection success;
- detection latency;
- false detections;
- threshold-boundary behavior;
- containment success;
- return-to-service behavior;
- post-fault transaction correctness.

### FPGA Comparison

- LUT;
- FF;
- critical timing;
- Fmax;
- incremental LUT overhead;
- incremental FF overhead;
- normal-operation latency impact;
- power only if reproducibly measurable.

---

## 9. Mandatory Fault Experiments

### F1 SDA-Release Cases

- release on recovery pulse 1;
- release on recovery pulse 3;
- release on recovery pulse 5;
- release on recovery pulse 9;
- never release.

### F2 Threshold Cases

- stretch substantially below threshold;
- threshold minus one;
- exact threshold boundary;
- threshold plus one;
- indefinitely held SCL;
- SCL released after detection.

The exact boundary convention will be frozen during architecture and
verification-plan validation.

---

## 10. Out of Scope

The initial research scope excludes:

- 10-bit addressing;
- Fast-mode and Fast-mode Plus;
- multi-controller implementation;
- arbitration as a primary research fault;
- UVM as a project requirement;
- reset-fault studies;
- noise/glitch fault models;
- generic internal FPGA faults;
- large collections of unrelated I2C fault classes.

ACK/NACK remains part of correct baseline protocol behavior.

Repeated ACK/NACK retry exhaustion is not currently a primary research
condition.

---

## 11. Reproducibility Requirement

Every reported experiment must be reproducible from a clean repository
checkout.

Each experiment must document, where applicable:

- Git commit / RTL revision;
- simulator/tool version;
- FPGA part;
- design parameters;
- clock configuration;
- fault configuration;
- test name;
- random seed;
- automated execution command;
- preserved or machine-readable results.

---

## 12. Project Success Criteria

The technical project is considered successful only if:

1. baseline nominal regression passes;
2. proposed-design nominal regression also passes;
3. F1 is deliberately reproduced and automatically checked;
4. F2 is deliberately reproduced and automatically checked;
5. legal clock stretching below the F2 threshold does not generate
   false detection;
6. F1 successful and unsuccessful recovery cases are demonstrated;
7. F2 containment and return-to-service behavior are demonstrated;
8. post-recovery transactions are automatically checked;
9. detection and recovery/containment latency are reported;
10. baseline and proposed designs are synthesized under matched FPGA
    conditions;
11. all reported results are reproducible;
12. unsupported novelty claims are avoided.

---

## 13. Research Position

The current target is a quantitatively evaluated fault-aware FPGA I2C
master supporting a small, specification-consistent set of abnormal-bus
handling mechanisms.

The expected strength of the work comes from the combination of:

specific fault definitions
+
context-aware detection
+
hardware recovery/containment
+
controlled fault injection
+
assertions and coverage
+
quantitative latency
+
matched FPGA overhead
+
reproducible experiments

The final novelty and publication claims will be determined only after
the architecture, verification, experiments, and broader evidence
support them.