# Fault-Tolerant I2C Master Controller for FPGA

Research-oriented RTL, verification, and FPGA evaluation of an I2C master controller with hardware support for selected abnormal bus conditions.

> **Project status:** A+B+D literature synthesis complete; authoritative I2C specification verification in progress.  
> **Final research gap:** Not yet frozen.  
> **Final fault model / recovery architecture:** Not yet frozen.

---

## Project Overview

I2C is a widely used two-wire serial communication protocol for communication between integrated circuits and peripheral devices.

Conventional FPGA I2C masters already provide the fundamental protocol operations such as START, STOP, repeated START, addressing, read/write transfers, ACK/NACK handling, and—in some designs—multi-controller arbitration and clock stretching.

This project therefore does **not** treat implementation of a conventional I2C master as the research contribution. Instead, it investigates whether a conventional FPGA I2C master can be extended with a small, carefully justified fault-management architecture for selected abnormal bus conditions and evaluated quantitatively against a matched baseline.

The final research contribution will be selected only after combining:

- the completed A+B+D cross-category literature synthesis; and
- authoritative I2C specification verification.

No novelty claim is made at the current stage.

---

## Project Objectives

The project aims to:

- maintain a literature-grounded research problem;
- verify relevant I2C protocol requirements from an authoritative specification;
- develop a conventional FPGA I2C master as a clean baseline;
- define a small, specification-aware fault model;
- develop a fault-aware extension based on the selected research gap;
- verify normal and abnormal operating conditions using SystemVerilog;
- learn and apply SystemVerilog Assertions (SVA), functional coverage, scoreboarding, and automated regression;
- perform deliberate and reproducible fault injection;
- measure detection and recovery behavior quantitatively;
- compare baseline and fault-aware implementations under matched FPGA conditions;
- document the complete flow for an IEEE-style research publication.

---

## Literature Review Structure

The literature review uses **three categories only**.

### Category A — FPGA / RTL I2C Controllers

Purpose:

- identify existing FPGA and RTL I2C controller architectures;
- establish conventional implementation baselines;
- determine which protocol features and FPGA results are already demonstrated.

### Category B — Fault Detection / Fault Tolerance / Recovery

Purpose:

- identify existing fault-management techniques;
- study fault detection, classification, recovery, watchdog, instrumentation, and fault-injection methods;
- avoid treating generic fault tolerance or generic fault injection as a new contribution.

### Category D — Verification / Fault Injection / Assertions / Coverage

Purpose:

- identify existing I2C verification methodologies;
- study constrained-random, UVM, formal, hybrid, assertion, coverage, and corner-case verification;
- determine which fault-oriented verification questions remain candidate gaps.

There is **no Category C literature-review category**.

Authoritative I2C protocol requirements are verified separately under:

`docs/specification/`

---

## Current Established Evidence

The reviewed literature already provides evidence for:

- FPGA I2C controller implementations;
- normal read/write and ACK/NACK operation;
- repeated START support;
- multi-controller arbitration;
- SystemVerilog I2C verification;
- constrained-random verification;
- UVM-based I2C verification;
- functional/code coverage;
- formal and hybrid I2C verification;
- arbitration-recovery verification;
- general fault-tolerance techniques;
- general fault-injection techniques;
- generic timer-assisted I2C transfer-error recovery.

Therefore, none of these broad topics is treated as a research gap by itself.

See:

`docs/research/cross_category_synthesis.md`

---

## Current Candidate Research Directions

These are **candidate directions only**. The final fault model is not yet frozen.

### F1 — SDA stuck LOW

Current status: **strong candidate**.

Possible future investigation:

- hardware stuck-bus detection;
- controlled bus-clear recovery;
- recovery success/failure reporting;
- recovery latency;
- post-recovery transaction correctness;
- FPGA implementation overhead.

### F2 — prolonged SCL LOW

Current status: **strong but carefully bounded candidate**.

Legal clock stretching must not be falsely classified as a fault. Any future prolonged-SCL timeout threshold would be an implementation-defined reliability policy rather than a mandatory base-I2C requirement.

Possible future investigation:

- configurable stall threshold;
- detection of loss of bus progress;
- discrimination from legal clock stretching;
- false-positive behavior;
- detection latency;
- recovery/escalation behavior.

### F3 — repeated unsuccessful ACK/NACK outcome

Current status: **weaker candidate**.

NACK itself is legal protocol behavior. Any retry limit, retry-exhaustion rule, safe abort, or escalation mechanism would be project-specific policy.

The final project should target only a small number of justified conditions, preferably **two or three maximum**.

---

## Baseline I2C Scope

The conventional baseline is expected to support the subset required by the final research experiment, including:

- open-drain SDA/SCL behavior;
- START;
- STOP;
- repeated START;
- 7-bit addressing;
- byte write;
- byte read;
- ACK/NACK handling;
- Standard-mode timing;
- observation of the actual SCL bus level when clock stretching is supported.

Multi-controller arbitration will not automatically be included in the final RTL unless required by the frozen project scope.

---

## Research Methodology

~~~text
Category A -> Category B -> Category D
            |
            v
A+B+D Cross-Category Synthesis
            |
            v
Authoritative I2C Specification Verification
            |
            v
Provisional Research Scope + Working RQs
            |
            v
Fault Model + Recovery Policy
            |
            v
Architecture
            |
            v
Verification Plan
            |
            v
Baseline RTL
            |
            v
Fault-Aware RTL
            |
            v
Fault Injection + Assertions + Coverage
            |
            v
Verification Closure
            |
            v
Matched FPGA Baseline-vs-Proposed PPA
            |
            v
Results + Reproducibility Package
            |
            v
IEEE-Style Paper Draft
~~~

**Working RQs are frozen provisionally after S2 and finalized after S3/S4 validation.**

The final research gap, final fault model, recovery policy, architecture, and verification plan are not frozen until the relevant evidence gates are complete.

---

## Verification Strategy

The project will use SystemVerilog verification. UVM is **not** a prerequisite for the initial implementation.

Planned verification techniques include:

- directed tests;
- constrained randomization where useful;
- monitor/checker logic;
- scoreboard/reference checking;
- SystemVerilog Assertions (SVA);
- functional coverage;
- fault-scenario coverage;
- deliberate controlled fault injection;
- automated regression;
- preserved PASS/FAIL reporting.

For each supported abnormal condition, the final experiment should evaluate where applicable:

- detection success;
- missed detection;
- false detection;
- classification correctness;
- recovery success;
- recovery failure;
- post-recovery transaction correctness;
- detection latency;
- recovery latency.

---

## FPGA Evaluation

The final baseline-versus-proposed comparison must use matched conditions:

- same FPGA device;
- same Vivado version;
- same clock constraint;
- same synthesis settings;
- same implementation settings.

The comparison will be:

~~~text
Conventional I2C Master
        versus
Same I2C Master + Fault-Management Extension
~~~

Candidate implementation metrics include:

- LUT count;
- FF count;
- incremental LUT/FF overhead;
- critical-path timing;
- Fmax impact;
- normal-path latency impact;
- power, only if reproducibly measurable.

Raw resource numbers from unrelated FPGA families will not be used as a direct baseline comparison.

---

## Reproducibility Rule

Every experiment must be reproducible from a clean repository checkout.

Each reported experiment must document, as applicable:

- Git commit / RTL revision;
- tool name and version;
- FPGA part;
- clock and timing constraints;
- configuration and parameter values;
- I2C operating mode;
- fault-injection configuration;
- random seed where applicable;
- test name;
- automated execution command or script;
- preserved or machine-readable result output.

Manual waveform inspection alone will not be treated as sufficient evidence for a reported quantitative result.

---

## Repository Structure

~~~text
docs/
├── literature/
│   ├── category_A.md
│   ├── category_B.md
│   ├── category_D.md
│   └── literature_matrix.csv
├── research/
│   ├── candidate_gaps.md
│   ├── cross_category_synthesis.md
│   ├── open_questions.md
│   ├── research_problem.md
│   └── research_questions.md
├── specification/
│   ├── i2c_requirements.md
│   ├── specification_verification.md
│   └── timing_requirements.md
└── verification/
    └── verification_plan.md
~~~

RTL, testbench, FPGA, scripts, results, and paper directories will be expanded after research/design scope closure.

---

## Publication Discipline

The project will distinguish:

- **Evidence-supported**
- **Project interpretation**
- **Not reported (NR)**
- **Candidate gap**
- **Project implementation policy**
- **Experimental result**

The repository and manuscript will not use unsupported claims such as:

- "first";
- "novel";
- "no previous work exists";
- "state-of-the-art";

unless later evidence independently supports such wording.

---

## References

Copyrighted IEEE papers are not redistributed in this repository.

Bibliographic information, literature analysis, and evidence summaries are maintained under:

`docs/literature/`

The current literature matrix contains the reviewed Category A, B, and D papers. Sukhanya and Gavaskar remains the existing A2 entry and may be referenced from Category D verification discussion without duplicating the matrix row.
