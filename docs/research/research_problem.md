# Research Problem

## Provisional Research Problem

Conventional FPGA I2C masters implement normal protocol communication, but selected abnormal bus conditions can prevent transaction progress or leave the bus unavailable.

This project investigates whether a conventional FPGA-based I2C master can be extended with a small hardware fault-management layer that detects and handles selected abnormal bus conditions while preserving legal I2C behavior and introducing limited FPGA resource, timing, and normal-operation overhead.

## Provisional Primary Conditions

### F1 — SDA stuck LOW

Investigate autonomous detection, controlled nine-clock bus-clear recovery, recovery failure, and post-recovery communication.

### F2 — Prolonged SCL LOW

Investigate a configurable implementation-defined loss-of-progress threshold, discrimination from legal clock stretching, safe transaction containment, and subsequent controller recovery after the external condition is removed.

## Baseline

The baseline will be a conventional Standard-mode, 7-bit FPGA I2C master supporting the protocol functionality required for a matched experiment, including legal clock-stretch observation.

## Proposed Design

The proposed design will use the same protocol engine plus only the selected monitoring, detection, classification, recovery or containment, and status mechanisms.

## Scope Boundary

The primary research contribution will not be based on UVM, generic fault injection, arbitration recovery, generic timeout logic, or NACK handling alone.

Repeated unsuccessful ACK/NACK handling may be implemented as normal controller policy but is not currently a primary fault-management research condition.

## Status

The research problem is provisionally frozen after S2.

It will be finalized only after S3 architecture/fault-model validation and S4 verification-plan validation.
