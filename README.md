# Fault-Tolerant I2C Master Controller for FPGA

Research-oriented design and verification of an I2C master controller
for FPGA-based systems, with a focus on reliable operation under
abnormal bus conditions.

> **Project status:** Literature Survey and Research Problem Definition  
> **Final research contribution:** Not yet frozen

---

## Project Overview

I2C is a widely used two-wire serial communication protocol for
communication between integrated circuits and peripheral devices.

Although conventional I2C controllers provide the required protocol
operations, abnormal bus conditions such as stuck SDA/SCL lines,
missing acknowledgements, excessive clock stretching, and interrupted
transactions can affect reliable communication.

This project investigates the design of an FPGA-based I2C master
controller and the addition of appropriate fault detection and recovery
mechanisms.

The final research contribution will be selected after completing a
systematic literature review.

---

## Project Objectives

The project aims to:

- Study the I2C protocol and its electrical/protocol requirements.
- Review existing FPGA and RTL-based I2C controller architectures.
- Study existing I2C fault detection and recovery techniques.
- Develop a conventional I2C master as a baseline.
- Develop a fault-tolerant extension based on the identified research gap.
- Verify normal and abnormal I2C operating conditions.
- Use SystemVerilog-based verification techniques.
- Perform fault injection and recovery experiments.
- Evaluate FPGA resource utilization and timing.
- Compare the baseline and proposed architectures quantitatively.
- Document the results for an IEEE-style research publication.

---

## I2C Features Under Study

The baseline controller is expected to investigate:

- SDA and SCL interface
- START condition
- STOP condition
- Repeated START
- 7-bit addressing
- Read transactions
- Write transactions
- ACK/NACK handling
- Clock stretching
- Arbitration
- Bus-clear/recovery behavior

Additional features will be included only when justified by the final
architecture and research scope.

---

## Fault Conditions Under Study

Potential fault conditions include:

- SDA stuck LOW
- SCL stuck LOW
- Missing ACK
- Unexpected NACK
- Excessive clock stretching
- Unexpected SDA/SCL bus state
- Incomplete transaction
- Reset during an active transaction
- Arbitration loss

The final fault model will be determined from the literature survey.

---

## Research Methodology

```text
I2C Specification
        |
        v
Literature Survey
        |
        v
Existing Architectures
        |
        v
Existing Limitations
        |
        v
Research Gap
        |
        v
Research Question
        |
        v
Baseline I2C Master
        |
        v
Proposed Fault-Tolerant Architecture
        |
        v
SystemVerilog RTL
        |
        v
Verification + Fault Injection
        |
        v
FPGA Synthesis / Timing / Power
        |
        v
Baseline vs Proposed Comparison
        |
        v
Research Results
        |
        v
IEEE Paper