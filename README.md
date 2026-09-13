# Fault-Tolerant I2C Master Controller for FPGA

Research-oriented RTL, verification, and FPGA evaluation of an I2C master controller with hardware support for selected abnormal bus conditions.

> **Project status:** RTL verification and matched FPGA implementation analysis are complete through Stage S8; final documentation and reproducibility closure (S9) is in progress.
> **Frozen research scope:** Fault-aware extension of a conventional FPGA I2C master for F1 (SDA stuck LOW) and F2 (implementation-defined prolonged SCL LOW).
> **Validation boundary:** Simulation and Vivado implementation evidence only; no physical FPGA board was available.

---

## Project Overview

I2C is a widely used two-wire serial communication protocol for communication between integrated circuits and peripheral devices.

Conventional FPGA I2C masters already provide the fundamental protocol operations such as START, STOP, repeated START, addressing, read/write transfers, ACK/NACK handling, and—in some designs—multi-controller arbitration and clock stretching.

This project therefore does **not** treat implementation of a conventional I2C master as the research contribution. Instead, it investigates whether a conventional FPGA I2C master can be extended with a small, carefully justified fault-management architecture for selected abnormal bus conditions and evaluated quantitatively against a matched baseline.

The frozen project scope was selected after combining:

- the completed A+B+D cross-category literature synthesis; and
- authoritative I2C specification verification.

The completed implementation study evaluates a conventional FPGA I2C
master against the same controller extended with deliberately bounded
F1/F2 fault detection and recovery mechanisms.

No unsupported claim of being first, novel, or state-of-the-art is made.

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

## Frozen Fault Model and Recovery Scope

The implementation and verification scope contains exactly two primary
abnormal bus conditions: **F1** and **F2**.

### F1 — SDA stuck LOW

F1 represents an externally held SDA-LOW condition that persists while
the controller expects the bus to be released.

Production configuration:

- `SDA_STUCK_LIMIT_CYCLES = 10_000`;
- system clock = 100 MHz;
- detector evidence = 9,999 cycles / 99.99 us;
- manager response = 10,000 cycles / 100 us.

The F1 recovery policy performs a bus-clear sequence of exactly nine SCL
clocks unless F2 preempts the F1 recovery while waiting for release.

### F2 — prolonged SCL LOW

F2 represents implementation-defined loss of bus progress caused by SCL
remaining LOW beyond the configured project threshold.

Production configuration:

- `SCL_STALL_LIMIT_CYCLES = 100_000`;
- system clock = 100 MHz;
- detector evidence = 99,999 cycles / 999.99 us;
- manager response = 100,000 cycles / 1 ms.

This threshold is a **project reliability policy**, not a mandatory
maximum clock-stretch time imposed by the base I2C specification.
Legal clock stretching below the configured loss-of-progress threshold
must not be falsely classified as F2.

### Conditions outside the frozen fault model

Repeated ACK/NACK outcomes are **not** a third implemented fault class.
NACK is legal I2C protocol behavior, and retry-exhaustion policy is
outside the frozen F1/F2 experimental scope.

No F3 fault class is implemented in the final RTL.

---

## Baseline I2C Scope

The conventional baseline implements the subset required by the frozen research experiment, including:

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

Multi-controller arbitration is outside the frozen single-master RTL scope.

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

**The research questions, F1/F2 fault model, recovery policy, architecture, and verification plan are frozen.**

Stages S5-S8 implemented, verified, and quantitatively evaluated the frozen
scope without adding another primary fault class.

---

## Verification Strategy

The project uses SystemVerilog verification. UVM was not required for the implemented verification flow.

Verification evidence includes:

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

For each supported abnormal condition, the completed experiment evaluates where applicable:

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

## Verification Closure

The quantitative fault-aware regression is closed.

Final S7 evidence includes:

- **17/17 fault-aware regression scenarios PASS**;
- **28/28 required fault-scenario coverage points covered**;
- F1 exact-threshold, limit-minus-one, limit-plus-one, false-positive,
  recovery-success, and recovery-failure behavior;
- F2 exact-threshold, limit-minus-one, limit-plus-one, legal/non-fault
  SCL-LOW behavior, extended hold, and return-to-service behavior;
- F1-to-F2 preemption behavior;
- zero false-positive count in the final quantitative regression;
- separate production-threshold latency evidence at the real
  100 MHz system-clock configuration.

Accelerated threshold values used by the practical S7 regression are
testbench/runtime settings only. They do **not** replace the production
RTL configuration of 10,000 cycles for F1 and 100,000 cycles for F2.

---

## FPGA Evaluation

The completed baseline-versus-fault-aware comparison uses matched conditions:

- same FPGA device;
- same Vivado version;
- same clock constraint;
- same synthesis settings;
- same implementation settings.

The comparison is:

~~~text
Conventional I2C Master
        versus
Same I2C Master + Fault-Management Extension
~~~

Reported implementation metrics include:

- LUT count;
- FF count;
- incremental LUT/FF overhead;
- critical-path timing;
- Fmax impact;
- normal-path latency impact;
- Vivado post-route vectorless power estimate.

### Final Matched FPGA Results

The final S8 comparison used Vivado 2024.1, the
`xc7a35tcpg236-1` target, and the same 10.000 ns / 100 MHz clock
constraint for both implementations.

| Metric | Baseline | Fault-aware | Change |
|---|---:|---:|---:|
| Post-synth LUTs | 87 | 223 | +156.32% |
| Post-route LUTs | 86 | 219 | +154.65% |
| Post-route FFs | 66 | 144 | +118.18% |
| Post-route WNS | +5.132 ns | +4.703 ns | -0.429 ns |
| Post-route TNS | 0.000 ns | 0.000 ns | unchanged |
| Routing errors | 0 | 0 | unchanged |
| Indicative implementation Fmax | 205.42 MHz | 188.79 MHz | -8.10% |
| Vectorless total power | 0.072 W | 0.075 W | +4.17% |

Both implementations meet the required 100 MHz setup timing constraint.

The Fmax numbers are implementation-derived indicative values, not
measured hardware frequencies.

The power numbers are **Vivado post-route vectorless power estimates**.
Both reports have **Low** confidence, so the values are not presented as
measured hardware power.

The post-route timing summary used max-delay/setup analysis; this project
does not claim physical-board timing validation from these reports.

No physical FPGA board was available for this project.

Raw resource numbers from unrelated FPGA families will not be used as a direct baseline comparison.

---

## Reproducibility Rule

Every experiment must be reproducible from a clean repository checkout.

Primary regression and implementation entry points are:

~~~bash
bash scripts/run_baseline_regression.sh
bash scripts/run_fault_aware_regression.sh
bash scripts/generate_fault_coverage_summary.sh

tclsh scripts/vivado/run_matched_flow.tcl baseline gate
tclsh scripts/vivado/run_matched_flow.tcl fault_aware gate
~~~

The matched Vivado implementation flow is launched with the same Tcl
script using the `run` mode from a Vivado-capable environment:

~~~text
vivado -mode batch -source scripts/vivado/run_matched_flow.tcl -tclargs baseline run
vivado -mode batch -source scripts/vivado/run_matched_flow.tcl -tclargs fault_aware run
~~~

The Vivado implementation commands are heavy runs and are not required
merely to inspect the committed final evidence.

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

The repository also contains the implemented RTL, testbenches, regression scripts, matched Vivado flow, and preserved simulation/synthesis/timing/power evidence used for S5-S8 closure.

---

## Publication Discipline

The project documentation distinguishes:

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
