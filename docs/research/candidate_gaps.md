# Candidate Research Gaps

> These are candidate gaps within the reviewed A+B+D evidence. They are not novelty claims.

## Current Evidence Boundary

The reviewed work already provides evidence for conventional FPGA I2C controllers, SystemVerilog/UVM verification, constrained-random verification, formal/hybrid verification, arbitration recovery, general fault injection, and generic timer-assisted I2C error recovery.

NR in the reviewed literature does not prove that a capability does not exist elsewhere.

## Candidate 1 — SDA Stuck-LOW Detection and Recovery

No explicit evidence was identified in the reviewed A+B+D set for the complete combination of autonomous SDA-stuck-LOW detection, controlled bus-clear recovery, deliberate fault injection, recovery-success measurement, latency measurement, post-recovery transaction checking, and matched FPGA overhead comparison.

Status: Strong surviving candidate.

## Candidate 2 — Prolonged SCL-LOW Detection Without False Classification

Base I2C permits clock stretching and does not define the project timeout threshold.

The candidate research question is therefore not generic timeout support, but whether an implementation-defined loss-of-progress threshold can detect prolonged SCL LOW while avoiding false classification of legitimate stretching.

Status: Strong but narrowed candidate.

## Candidate 3 — Quantitative Recovery and Implementation Trade-Off

Candidate measurements include detection latency, recovery or containment latency, recovery success, post-recovery correctness, false detection, LUT/FF overhead, Fmax impact, and normal-operation penalty.

Status: Surviving candidate evaluation gap within the reviewed evidence.

## Candidate 4 — False-Positive Analysis

A fault-aware controller must distinguish legal protocol behavior from project-defined abnormal conditions.

For this project, the most important case is legal clock stretching versus prolonged SCL LOW beyond the configured loss-of-progress threshold.

Status: Candidate research metric and design requirement.

## Weakened / Removed Candidates

- Generic FPGA I2C implementation — already established.
- Generic SystemVerilog/UVM verification — already established.
- Generic fault injection — already established.
- Arbitration-loss recovery — already represented in prior I2C work.
- Generic timer-based error recovery — prior evidence exists.
- NACK as a fault — rejected; NACK is legal I2C behavior.
- Repeated ACK/NACK retry exhaustion — retained only as optional protocol/error-handling policy, not a primary research contribution.

## Current Direction

The provisional primary fault set is F1 SDA stuck LOW and F2 prolonged SCL LOW.

The final research gap remains subject to S3 architecture and S4 verification-plan validation.
