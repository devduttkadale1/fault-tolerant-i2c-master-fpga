# A+B+D Cross-Category Literature Synthesis

## 1. Purpose

This document synthesizes the findings of:

- Category A — FPGA / RTL I2C Controllers
- Category B — Fault Detection, Fault Tolerance, Error Handling,
  and Recovery
- Category D — Verification, Fault Injection, Assertions, Coverage,
  and Validation

The objective is to determine which capabilities are already
represented in the reviewed evidence, which candidate gaps survive
cross-category challenge, and which research directions remain
worth investigating.

This synthesis does not select the final research gap.

The final research problem, fault model, recovery policy,
architecture, and verification plan remain provisional until relevant
I2C protocol requirements have been independently checked against an
authoritative specification.

---

# 2. Consolidated Established Capabilities

## 2.1 Conventional FPGA I2C Implementation

### Evidence-supported

Category A demonstrates that FPGA implementation of I2C controllers
is already established.

The reviewed work includes examples of:

- FPGA-based I2C masters
- read transactions
- write transactions
- ACK handling
- NACK handling
- repeated START
- RTL FSM implementation
- FPGA synthesis
- physical hardware demonstrations

Therefore:

> Designing a conventional FPGA I2C master is not by itself a
> sufficient research contribution.

---

## 2.2 Multi-Master Arbitration

### Evidence-supported

Category A contains prior FPGA work involving dual-master operation
and arbitration-loss handling.

Category D provides stronger verification evidence showing formal and
hybrid verification of arbitration-loss and arbitration-recovery
behavior.

Therefore:

> Basic arbitration support or arbitration-recovery verification is
> already represented in the reviewed literature.

---

## 2.3 Conventional I2C Functional Verification

### Evidence-supported

The reviewed Categories A and D contain:

- directed simulation
- SystemVerilog verification
- constrained randomization
- monitors
- drivers
- scoreboards
- functional coverage
- code coverage
- reusable UVM environments

Measured functional/code coverage is also reported in prior work.

Therefore:

> A conventional I2C SystemVerilog/UVM verification environment is
> not by itself a sufficient research contribution.

---

## 2.4 Formal and Hybrid I2C Verification

### Evidence-supported

Category D demonstrates:

- formal properties
- OVL/PSL assertions
- protocol checks
- data-integrity checks
- arbitration checks
- simulation-assisted state setup
- formal counterexample generation
- hybrid simulation/formal verification
- verification of difficult I2C corner cases

Therefore:

> Formal or hybrid verification of I2C is already established within
> the reviewed evidence.

---

## 2.5 General Fault Detection and Fault Tolerance

### Evidence-supported

Category B demonstrates established use of mechanisms including:

- Built-In Test
- Built-In Self-Test
- embedded instrumentation
- watchdog timers
- EDAC
- automatic error correction
- fault classification
- software recovery
- system reconfiguration

Therefore:

> General fault tolerance is not a research gap.

---

## 2.6 General Fault Injection

### Evidence-supported

Category B contains explicit deliberate fault-injection mechanisms,
including:

- FPGA/ASIC fault-injection logic
- physical fault-injection switches
- dedicated error-injection registers/circuitry
- deliberate memory/error injection

Therefore:

> Fault injection itself is not a research contribution.

---

## 2.7 Communication Reliability Techniques

### Evidence-supported

Category B also demonstrates reliability improvements based on:

- buffering
- timing/speed matching
- page-write scheduling
- prevention of data loss

These mechanisms improve communication reliability but are not
equivalent to protocol-level bus-fault recovery.

---

## 2.8 Generic I2C Timer-Assisted Error Recovery

### Evidence-supported

Category D1 reports an I2C-slave implementation containing:

- internal status information
- a timer
- transfer-error recovery

### Evidence boundary

The exact error condition and timer semantics are NR.

Therefore:

> Generic timer-assisted I2C error recovery already has prior
> implementation evidence.

A future candidate gap must be more specific than simply:

> "add a timeout to I2C."

---

# 3. Candidate Gaps That Survived A → B → D

The following remain **candidate gaps**, not verified research gaps.

## 3.1 Prolonged-SCL / Excessive-Clock-Stretch Detection

### Current evidence

Clock stretching itself is established.

Generic timer-assisted I2C transfer-error recovery is also represented.

However, the reviewed evidence does not explicitly describe:

- monitoring SCL-low duration as a fault criterion
- distinguishing legal stretching from abnormal/excessive stretching
- a defined clock-stretch timeout threshold
- recovery triggered specifically by excessive stretching
- quantitative detection/recovery latency for that condition

### Status

**Candidate gap remains, but weakened/narrowed.**

The candidate is not:

> "I2C timeout support."

It is closer to:

> explicit detection and recovery for prolonged SCL LOW / excessive
> clock stretching, with a defined implementation policy and
> quantitative evaluation.

---

## 3.2 Missing-ACK / Repeated-NACK Fault-Management Policy

### Current evidence

ACK/NACK functionality is established as normal I2C behavior.

However, the reviewed evidence does not establish a dedicated
fault-management architecture for:

- repeated missing ACK
- retry limits
- retry versus abort policy
- escalation after repeated NACK
- recovery-state reporting
- detection/recovery latency

### Status

**Candidate gap remains.**

### Evidence boundary

Normal NACK behavior must not automatically be classified as a fault.

The later specification check must determine the boundary between
normal protocol response and project-specific fault-management policy.

---

## 3.3 SDA/SCL Stuck-Bus Detection and Recovery

### Current evidence

No reviewed A, B, or D paper explicitly demonstrates the complete
combination of:

- deliberate SDA-stuck-LOW testing
- deliberate SCL-stuck-LOW testing
- hardware stuck-bus classification
- autonomous I2C bus recovery
- verification of recovery success
- recovery-latency measurement
- FPGA overhead measurement

### Status

**Candidate gap remains.**

### Evidence boundary

Absence from the reviewed paper set is not proof of absence from the
broader literature.

---

## 3.4 Systematic I2C Bus/Protocol Fault Injection

### Current evidence

General fault injection is established.

I2C negative/corner-case verification is also established.

However, the reviewed evidence does not demonstrate a systematic
framework that deliberately injects a selected set of abnormal
I2C bus/protocol conditions and quantitatively evaluates controller:

- detection
- classification
- recovery
- recovery failure
- latency

### Status

**Candidate gap remains in narrowed form.**

The broad claim:

> "fault injection for I2C is new"

is not supported.

---

## 3.5 Detection-Latency Evaluation

### Current evidence

No reviewed source reports hardware detection latency for the
candidate abnormal I2C bus conditions.

Formal proof depth reported in Category D is not equivalent to
hardware detection latency.

### Status

**Candidate gap remains.**

---

## 3.6 Recovery-Latency Evaluation

### Current evidence

Recovery behavior appears in non-I2C fault-tolerance literature and
arbitration recovery appears in I2C verification literature.

However, quantitative recovery latency for the candidate bus faults
is NR.

### Status

**Candidate gap remains.**

---

## 3.7 Incremental FPGA Cost of Fault Management

### Current evidence

FPGA resource numbers for conventional I2C controllers exist.

I2C-versus-SPI implementation overhead has also been quantified.

However, the reviewed evidence does not quantify:

baseline I2C master

versus

the same I2C master + selected fault-management logic.

### Candidate metrics

- incremental LUT count
- incremental FF count
- percentage resource overhead
- critical-path change
- Fmax change
- power change, if measurable

### Status

**Candidate gap remains.**

---

## 3.8 False-Detection / Legal-Behavior Discrimination

### Project inference

A fault-aware controller must avoid classifying legal I2C behavior as
a fault.

Examples may include:

- legal clock stretching
- legitimate NACK conditions
- legal arbitration loss

The reviewed papers establish that some of these behaviors are normal
parts of I2C operation.

A future fault-management design may therefore need to measure:

- false-positive detections
- correct discrimination between legal and abnormal behavior

### Status

**Candidate research metric/direction.**

This is an inference from the literature rather than a verified gap.

---

# 4. Candidate Gaps Eliminated or Substantially Weakened

| Original Candidate | A+B+D Result | Status |
|---|---|---|
| FPGA I2C master implementation | Multiple prior implementations | Eliminated |
| Basic FSM architecture | Widely represented | Eliminated |
| Read/write support | Established | Eliminated |
| ACK/NACK support | Established | Eliminated |
| Repeated START | Established | Eliminated |
| FPGA hardware demonstration | Established | Eliminated |
| Multi-master arbitration | Prior FPGA work | Eliminated |
| Arbitration-loss recovery verification | Explicit D3 evidence | Eliminated |
| SystemVerilog I2C verification | Established | Eliminated |
| UVM I2C verification | Established | Eliminated |
| Constrained-random verification | Established | Eliminated |
| Functional/code coverage | Established | Eliminated |
| Formal I2C verification | Established | Eliminated |
| Hybrid formal/simulation I2C verification | Established | Eliminated |
| General fault tolerance | Established outside I2C | Eliminated |
| General fault injection | Explicit B evidence | Eliminated |
| Generic timeout/error timer | D1 reports timer-assisted I2C transfer-error recovery | Substantially weakened |
| Generic negative/error testing | D2/D3 establish prior error/corner-case testing | Substantially weakened |
| Generic communication reliability | B2 prior evidence | Eliminated as broad gap |

---

# 5. Evidence Boundaries

## 5.1 "Not Reported" Is Not "Not Implemented"

If a paper does not describe a feature, the correct repository
classification is:

**NR**

not:

**No**

unless the paper explicitly states that the feature is absent.

---

## 5.2 Reviewed-Set Absence Is Not Literature-Wide Absence

The strongest permissible wording is:

> "No explicit evidence was identified in the reviewed A+B+D paper
> set."

The following wording is not currently justified:

> "No previous work exists."

---

## 5.3 General Fault Tolerance Is Not I2C Protocol Fault Tolerance

EDAC, watchdogs, radiation hardening, system diagnostics, and
buffering are relevant methodology but do not directly establish an
I2C bus-recovery architecture.

---

## 5.4 Error Handling Is Not Automatically Fault Tolerance

Normal protocol events such as:

- NACK
- arbitration loss
- clock stretching

must not automatically be labelled faults.

A later specification check is required before defining the project's
fault model.

---

## 5.5 Formal Proof Depth Is Not Detection Latency

Formal-state depth describes verification exploration.

Hardware detection latency must instead be explicitly defined and
measured in implementation-relevant units.

---

## 5.6 PPA Numbers Require Matched Comparisons

Raw resource counts across unrelated FPGA families, tools, or
architectures should not be used as direct performance claims.

The strongest future experiment is a matched comparison:

same RTL baseline
same FPGA
same synthesis settings
same constraints

with and without fault-management logic.

---

# 6. Remaining Candidate Research Directions

No direction is selected at this stage.

## Direction R1 — Stuck-Bus Detection and Autonomous Recovery

Possible future scope:

- SDA stuck LOW
- SCL stuck LOW
- detection logic
- classification
- autonomous recovery
- recovery success/failure reporting
- deliberate fault injection
- latency measurement
- PPA overhead

### Current status

Candidate only.

The exact recovery procedure must later be checked against the
authoritative I2C specification.

---

## Direction R2 — Prolonged SCL LOW / Excessive Clock Stretch

Possible future scope:

- measure SCL-low duration
- distinguish normal stretching from implementation-defined timeout
- detect abnormal lack of progress
- abort/recover according to explicit policy
- measure timeout detection and recovery latency

### Current status

Candidate only.

This direction is weaker than originally thought because generic
timer-assisted I2C transfer-error recovery already exists.

---

## Direction R3 — ACK-Failure Management

Possible future scope:

- observe ACK/NACK behavior
- distinguish normal NACK from project-defined abnormal repetition
- configurable retry count
- abort/escalation policy
- status reporting
- verification by deliberate ACK-related stimulus

### Current status

Candidate only.

Specification analysis is required before defining which ACK/NACK
events can legitimately be labelled faults.

---

## Direction R4 — Small Multi-Fault Fault-Management Architecture

Possible future scope:

A conventional I2C master plus a small dedicated fault-management
extension supporting a limited number of carefully selected fault
conditions.

For example, after specification verification, the final scope might
contain only two or three fault classes rather than attempting to
cover every possible I2C abnormal condition.

Possible architecture-level concepts include:

- monitor
- detector
- classifier
- recovery controller
- status/reporting

### Current status

Candidate architecture direction only.

No blocks or fault classes are frozen.

---

## Direction R5 — Fault-Oriented Verification and Measurement

Possible future scope:

For each selected abnormal condition:

- deliberate controlled stimulus
- automatic fault detection check
- recovery-success check
- post-recovery transaction check
- assertions
- functional coverage
- fault-scenario coverage
- detection latency
- recovery latency

### Current status

Candidate methodology.

The contribution cannot be "fault injection" or "UVM" by itself.

---

# 7. Candidate Experimental Metrics

## 7.1 Normal Functional Metrics

- write correctness
- read correctness
- ACK/NACK correctness
- START/STOP correctness
- repeated START correctness
- transaction success rate
- regression pass/fail

---

## 7.2 Fault-Detection Metrics

For each selected fault class:

- number of injected fault cases
- number correctly detected
- missed detections
- false detections
- fault-classification correctness

Possible derived metric:

Detection success rate =
correct detections / injected detectable faults

---

## 7.3 Recovery Metrics

- recovery attempts
- successful recoveries
- failed recoveries
- aborted transactions
- successful retries
- bus returned to idle
- successful first transaction after recovery

Possible derived metric:

Recovery success rate =
successful recoveries / attempted recoveries

---

## 7.4 Latency Metrics

### Detection latency

Time from defined fault-onset event to asserted fault indication.

Possible units:

- FPGA system-clock cycles
- SCL cycles
- microseconds

### Recovery latency

Time from fault detection to defined recovered state.

The recovered state must be formally defined before measurement.

---

## 7.5 Verification Metrics

- assertion pass/fail
- functional coverage
- code coverage
- fault-scenario coverage
- cross-coverage between fault class and controller state
- recovery-state coverage

Formal verification may be added selectively if useful, but is not
required merely because prior work uses it.

---

## 7.6 FPGA Metrics

Matched baseline-versus-proposed measurements:

- LUT
- FF
- other FPGA resources if materially affected
- critical path
- Fmax
- incremental area percentage
- Fmax degradation/improvement
- power, if reproducibly measurable

---

## 7.7 Normal-Path Penalty

A fault-aware controller should also be evaluated for whether fault
management changes normal transactions.

Possible metrics:

- normal transaction latency
- SCL generation behavior
- read/write throughput
- added cycles in fault-free operation

---

# 8. Updated Working Research Questions

These are **working questions**, not final research questions.

## WRQ1 — Detection

How can an FPGA-based I2C master detect selected abnormal bus or
protocol conditions while avoiding false classification of legal I2C
behavior?

---

## WRQ2 — Classification

Can the selected abnormal conditions be classified sufficiently to
apply different recovery policies and produce meaningful status
information?

---

## WRQ3 — Recovery

What implementation-defined recovery policy is appropriate for each
selected condition after the relevant protocol requirements have been
verified?

---

## WRQ4 — Fault-Oriented Verification

Can the selected conditions be deliberately and reproducibly created
in a verification environment so that detection and recovery can be
automatically checked?

---

## WRQ5 — Detection Latency

What is the hardware detection latency for each supported abnormal
condition?

---

## WRQ6 — Recovery Latency

What is the recovery latency for each supported condition, using a
clearly defined recovery-complete criterion?

---

## WRQ7 — Recovery Effectiveness

What fraction of deliberately created fault scenarios are:

- correctly detected
- correctly classified
- successfully recovered
- safely aborted when recovery is not possible?

---

## WRQ8 — False Detection

Does the fault-management logic incorrectly flag legal protocol
behavior as a fault?

---

## WRQ9 — FPGA Cost

What incremental FPGA resource and timing overhead is introduced by
the fault-management architecture relative to a matched conventional
I2C-master baseline?

---

## WRQ10 — Normal-Operation Impact

Does the fault-management extension affect normal I2C transaction
correctness, latency, or throughput?

---

# 9. Current Research Position After A+B+D

The reviewed evidence supports the following high-level conclusion:

> Conventional FPGA I2C implementation, conventional functional
> verification, UVM, constrained-random verification, formal/hybrid
> verification, arbitration-recovery verification, general fault
> tolerance, general fault injection, and generic timer-assisted I2C
> error recovery all have prior evidence.

The remaining candidate research space is narrower:

> explicit RTL handling of a carefully selected set of abnormal
> I2C bus/protocol conditions, combined with controlled fault-oriented
> verification and quantitative measurement of recovery effectiveness,
> latency, and incremental FPGA cost.

This is still a candidate direction.

No novelty claim or final research gap is made.

---

# 10. Next Research Gate

The next stage is not RTL implementation.

Before selecting the final gap or architecture, the project must
independently verify relevant I2C requirements against an
authoritative specification.

That separate specification-verification stage must establish the
boundary between:

- protocol-mandated behavior
- legal protocol behavior
- recommended recovery behavior
- behavior not defined by the protocol
- project-specific implementation policy

Only after that verification should the project freeze:

- final research gap
- final research questions
- supported fault set
- recovery policies
- architecture
- verification plan
- RTL implementation scope