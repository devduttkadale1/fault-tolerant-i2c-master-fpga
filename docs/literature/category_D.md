# Category D — Verification, Fault Injection, Assertions, Coverage, and Validation

## 1. Purpose

Category D examines verification methodologies relevant to the
development and validation of I2C controllers, with emphasis on
negative testing, corner-case verification, assertions, coverage,
formal verification, and fault-oriented verification.

The purpose of this category is to determine:

1. Which I2C verification methodologies are already established.
2. Whether abnormal or difficult protocol conditions are deliberately
   exercised.
3. Whether recovery behavior is explicitly verified.
4. Whether protocol/bus faults are deliberately injected.
5. Whether detection and recovery latency are measured.
6. Which candidate gaps identified after Categories A and B remain
   unresolved.

Category D does not assume that an "error test", corner-case test,
formal counterexample, or arbitration-loss scenario is equivalent to
physical or protocol-level fault injection.

---

## 2. Evidence Terminology

### Evidence-supported

Explicitly reported by the reviewed source.

### Project interpretation

An interpretation made for this research project from the reported
evidence.

### Not reported (NR)

No evidence for the feature was identified in the reviewed paper.

NR must not be interpreted as proof that a feature was absent from
the implementation.

### Candidate gap

A potentially underexplored area that remains unresolved within the
reviewed evidence.

A candidate gap is not a novelty claim.

---

# 3. D1 — Oudjida et al., 2009

## 3.1 Bibliographic Information

**Paper ID:** D1

**Title:**  
FPGA Implementation of I2C & SPI Protocols: a Comparative Study

**Authors:**  
A.K. Oudjida; M.L. Berrandjia; R. Tiar; A. Liacha; K. Tahraoui

**Year:**  
2009

**Publication:**  
IEEE conference publication

**DOI:**  
NR / not verified from the supplied paper

---

## 3.2 Research Problem

### Evidence-supported

The paper compares FPGA implementations of I2C-slave and SPI-slave
IP cores.

The authors use a market investigation of commercial I2C/SPI devices
to select features for general-purpose IP implementations and then
compare their FPGA area and timing characteristics.

Only the slave side of both protocols is implemented.

---

## 3.3 I2C-Slave Features

### Evidence-supported

The implemented I2C-slave feature set includes:

- bidirectional data transfer
- programmable ACK
- repeated START detection
- 7-bit and 10-bit addressing
- clock stretching
- interrupt/polling operation
- digital spike filtering
- FIFOs
- internal status handling
- transfer-error recovery using a timer

The RTL implementation is written in Verilog 2001.

---

## 3.4 Clock Stretching

### Evidence-supported

The I2C-slave supports a user-defined wait-state insertion period,
identified as clock stretching.

### Evidence boundary

The paper does not state that the duration of clock stretching is
monitored for abnormal or excessive behavior.

Therefore clock-stretch support is not evidence of an
excessive-clock-stretch detector.

---

## 3.5 Timer-Assisted Transfer-Error Recovery

### Evidence-supported

The I2C-slave feature table explicitly identifies:

> transfer error recovery using internal status flags and a timer.

### Not reported

The paper does not report:

- the exact fault/error condition timed
- the timeout threshold
- the signal being monitored
- the protocol phase being timed
- whether SCL-low duration is monitored
- whether excessive clock stretching is monitored
- the exact recovery state sequence
- whether recovery means abort, retry, reset, or another action

### Project interpretation

This paper establishes prior evidence for a **generic timer-assisted
I2C transfer-error recovery mechanism**.

It does not establish a specific prolonged-SCL or clock-stretch
timeout architecture.

It also does not establish that such a timer is mandated by the I2C
standard.

---

## 3.6 Digital Filtering

### Evidence-supported

The implementation includes spike filtering intended to reject input
spikes shorter than a defined number of system-clock cycles.

### Project interpretation

This is an input-signal integrity mechanism.

It is distinct from transaction-level fault classification or
bus-recovery control.

---

## 3.7 Verification and Hardware Validation

### Evidence-supported

The I2C and SPI designs were:

- simulated at RTL level
- simulated at gate level
- evaluated with timing back-annotation
- simulated using ModelSim SE 6.3f
- mapped to Xilinx FPGAs using Foundation ISE 10.1
- integrated in a MicroBlaze SoC environment
- physically tested using a V2MB1000 demonstration board

### Fault injection

NR.

No deliberate stuck-SDA, stuck-SCL, missing-ACK, excessive-stretch,
or bus-clear fault test is reported.

---

## 3.8 FPGA Results

### Evidence-supported

Representative I2C-slave occupied-slice results include:

- Spartan-2: 510 slices
- Spartan-3: 503 slices
- Virtex-2: 504 slices
- Virtex-4: 512 slices
- Virtex-5: 187 slices

For the Virtex-5 implementation, an I2C clock-to-setup delay of
3.606 ns is reported.

The authors report approximately 25% average area overhead for their
I2C-slave implementation compared with their matched SPI-slave
implementation.

The additional I2C implementation complexity is associated with
features including addressing, flow control, and clock stretching.

### Evidence boundary

The 25% value is:

I2C-slave versus SPI-slave.

It is not the hardware overhead of fault-tolerance logic.

---

## 3.9 Relevance

D1 provides evidence for:

- FPGA I2C implementation cost
- clock stretching
- input spike filtering
- timer-assisted generic transfer-error recovery
- FPGA hardware validation

It does not provide evidence for the specific abnormal-bus recovery
architecture currently being considered in this project.

---

# 4. D2 — Ni and Zhang, 2015

## 4.1 Bibliographic Information

**Paper ID:** D2

**Title:**  
Research of Reusability Based on UVM Verification

**Authors:**  
Wei Ni; Jichun Zhang

**Year:**  
2015

**Publication:**  
IEEE publication

**DOI:**  
NR / not verified from the supplied paper

---

## 4.2 Research Problem

### Evidence-supported

The paper investigates reusable functional verification using UVM.

An I2C verification platform is used to demonstrate reuse of:

- components
- environments
- agents
- test cases
- sequences

---

## 4.3 Verification Architecture

### Evidence-supported

The UVM environment contains:

- Test
- Environment
- Agent
- Driver
- Monitor
- Scoreboard
- Sequencer
- Virtual Sequencer
- Virtual Sequence
- Coverage Model
- protocol Checker
- BFM
- virtual interfaces

The monitor collects bus activity and converts it into transactions.

The Scoreboard collects transactions from monitors and performs
automatic comparison.

A Checker performs I2C protocol analysis.

Functional coverage logic is associated with monitor components.

---

## 4.4 Reusability

### Evidence-supported

The environment supports reuse through:

- component reuse
- platform reuse
- inheritance
- sequence reuse
- test reuse
- multiple master/slave agent structures

---

## 4.5 Test Classes

### Evidence-supported

Reported test classes include:

- `i2c_uvm_base_test`
- `i2c_uvm_basic_test`
- `i2c_uvm_random_test`
- `i2c_uvm_error_test`
- user-defined test extensions

The paper demonstrates constrained basic sequences and random
sequence generation.

### Evidence boundary

Although an `i2c_uvm_error_test` exists, the paper does not report:

- which error is generated
- whether SDA is forced LOW
- whether SCL is forced LOW
- whether ACK is deliberately suppressed
- whether clock stretching is manipulated
- whether a timeout condition is created
- whether recovery behavior is checked

Therefore the existence of the error-test class is not sufficient
evidence for I2C protocol/bus fault injection.

---

## 4.6 Coverage

### Evidence-supported

The architecture contains a Coverage Model, and the authors discuss
using additional constraints, sequences, and test classes to improve
functional coverage.

### Evidence boundary

The paper discusses 100% functional coverage as an objective of test
development.

It does not report a detailed numerical coverage result equivalent
to the quantitative coverage evidence reported by Sukhanya and
Gavaskar.

---

## 4.7 Recovery

NR.

No explicit verification is reported for:

- missing-ACK recovery
- timeout recovery
- stuck-bus recovery
- bus clear
- clock-stretch timeout
- recovery latency

---

## 4.8 Relevance

D2 establishes a reusable UVM-based I2C verification architecture.

It does not establish systematic abnormal-bus fault injection or
quantitative recovery verification.

---

# 5. D3 — Tiwari and Mitra, 2007

## 5.1 Bibliographic Information

**Paper ID:** D3

**Title:**  
Hybrid Verification of Protocol Bridges

**Authors:**  
Praveen Tiwari; Raj S. Mitra

**Year:**  
2007

**Venue:**  
IEEE Design & Test of Computers

**DOI:**  
NR / not verified from the supplied paper

---

## 5.2 Research Problem

### Evidence-supported

The paper addresses limitations of simulation and formal verification
when applied independently to complex protocol bridges.

Two case studies contain I2C interfaces.

The proposed methodology combines:

- directed simulation
- functional/temporal partitioning
- constraints
- formal verification

---

## 5.3 ARM7-I2C Bridge

### Evidence-supported

The first design is an ARM7-to-I2C bridge containing:

- transmit and receive FIFOs
- configuration registers
- master/slave configuration
- transmitter/receiver modes

Verification targets include:

- protocol compliance
- data integrity
- arbitration behavior

Properties are implemented using OVL and PSL.

---

## 5.4 Arbitration-Loss Verification

### Evidence-supported

The authors:

1. wrote a property modeling arbitration loss;
2. deliberately caused the property to fail;
3. obtained a formal counterexample representing an arbitration-loss
   scenario;
4. used the counterexample in simulation to enter the lost-arbitration
   state;
5. formally proved arbitration-recovery properties.

A controller defect was discovered in which the module attempted to
continue writing to the serial bus after losing arbitration.

The arbitration failure was reached at a formal depth of 156 clock
events.

### Project interpretation

This is strong prior evidence for negative/corner-case I2C
verification and arbitration-recovery verification.

It is best classified as **counterexample-driven hybrid
verification**, not physical bus-fault injection.

Arbitration loss itself is also a legal multi-master protocol event,
rather than necessarily a physical bus fault.

---

## 5.5 OCP-I2C Bridge

### Evidence-supported

The second design contains an OCP interface and an I2C controller.

A difficult master-receive corner case involved a status register
failing to clear correctly near the I2C STOP condition.

Hybrid verification was used to divide the event window and analyze
the relevant states.

A proposed workaround was disproved and another workaround was
verified.

---

## 5.6 Proof Depth

### Evidence-supported

The OCP-I2C corner-case bug was reached at:

- formal proof depth: 2,708 cycles
- cumulative simulation + formal depth: 4,908 cycles

### Evidence boundary

These numbers describe verification depth.

They are not hardware:

- fault-detection latency
- recovery latency

They must not be recorded as such.

---

## 5.7 Methodology Limitation

### Evidence-supported

The authors explicitly note that hybrid verification cannot provide a
complete proof of all behavior and that scenario selection and
verification planning remain important.

---

## 5.8 Not Reported

No evidence was identified for deliberate testing of:

- SDA stuck LOW
- SCL stuck LOW
- excessive clock stretching
- missing-ACK timeout
- autonomous bus clear
- bus-recovery pulse generation
- recovery-latency measurement

---

## 5.9 Relevance

D3 establishes prior evidence for:

- formal I2C verification
- hybrid simulation/formal verification
- negative/corner-case I2C testing
- arbitration-loss/recovery verification
- deep-state protocol verification

Therefore these concepts cannot independently constitute the
research contribution of the present project.

---

# 6. A2/D Reference — Sukhanya and Gavaskar, 2017

Sukhanya and Gavaskar is already stored as **A2** in the literature
matrix.

It is reused here as Category D verification evidence but must not be
added as a duplicate D-row.

### Evidence-supported verification features

The paper reports:

- SystemVerilog verification
- constrained randomization
- monitor
- driver
- scoreboard
- functional coverage
- code coverage

Reported quantitative results include:

- DUT code coverage: 92.38%
- top-level code coverage: 92.90%
- functional coverage: 100%
- FSM-state coverage: 100%

### Not reported

No deliberate verification mechanism was identified for:

- stuck SDA
- stuck SCL
- excessive clock stretching
- timeout recovery
- bus clear
- fault-detection latency
- recovery latency

### Relevance

A2 provides a strong nominal functional-verification and coverage
baseline, but not the fault-oriented recovery verification currently
being investigated.

---

# 7. Category D Cross-Paper Comparison

| Source | Main Contribution | Negative/Error Testing | Fault Injection | Recovery Verification | Coverage / Formal | FPGA / Hardware | Latency Evidence |
|---|---|---|---|---|---|---|---|
| D1 — Oudjida 2009 | FPGA I2C/SPI implementation | Generic transfer-error handling | NR | Generic timer/status recovery; exact sequence NR | RTL/gate functional verification | Yes | NR |
| D2 — Ni 2015 | Reusable I2C UVM platform | Error-test class exists; stimulus NR | NR | NR | Checker, scoreboard, coverage, random tests | NR | NR |
| D3 — Tiwari 2007 | Hybrid formal + simulation | Arbitration loss and deep corner cases | Counterexample-driven state generation; not physical injection | Arbitration recovery verified | OVL/PSL + formal | NR | Proof depth only |
| A2/D-reference — Sukhanya 2017 | SystemVerilog I2C verification | Mainly nominal/functional scenarios | NR | NR | Constrained random + measured coverage | NR | NR |

---

# 8. Category D Challenge to Existing Candidate Gaps

## 8.1 Prolonged SCL LOW / Clock-Stretch Timeout

D1 contains:

- clock stretching;
- a timer-assisted generic transfer-error recovery mechanism.

However, no evidence links the timer specifically to clock-stretch
duration or prolonged SCL LOW.

### Status

**Candidate gap remains, but is narrower than before.**

Generic timer-assisted I2C error recovery is already represented in
prior work.

A specific excessive-clock-stretch/prolonged-SCL detection and
recovery architecture was not identified in the reviewed evidence.

---

## 8.2 Missing-ACK Recovery

Normal ACK behavior is represented in existing I2C implementations
and verification environments.

No reviewed Category D paper reports a fault-management policy for:

- missing ACK
- repeated NACK
- retry limits
- timeout
- autonomous transaction abort/recovery

### Status

**Candidate gap remains within the reviewed evidence.**

---

## 8.3 Stuck-Bus Recovery

No reviewed Category D paper reports:

- SDA-stuck-LOW fault injection
- SCL-stuck-LOW fault injection
- autonomous bus-clear logic
- bus-recovery clock generation
- verification of recovery from stuck lines

### Status

**Candidate gap remains within the reviewed evidence.**

---

## 8.4 Fault-Oriented Verification

The broad candidate gap "I2C error/negative verification" does not
survive Category D.

Existing work already demonstrates:

- constrained-random I2C verification
- UVM I2C verification
- formal I2C verification
- hybrid simulation/formal verification
- arbitration-loss/recovery verification
- difficult corner-case analysis

### Remaining narrower candidate

Systematic injection of selected abnormal I2C bus/protocol conditions
combined with explicit measurement of:

- detection
- classification
- recovery success
- detection latency
- recovery latency

remains a candidate area within the reviewed evidence.

---

# 9. Category D Conclusion

Category D significantly narrows the research space.

Advanced I2C verification methodology, including constrained random
verification, UVM, coverage, formal verification, hybrid verification,
and arbitration-recovery analysis, is already represented in prior
work.

Generic timer-assisted I2C transfer-error recovery also has prior
implementation evidence.

The remaining candidate research space is therefore more specific:
selected abnormal I2C bus/protocol conditions whose detection and
recovery can be implemented explicitly in RTL, deliberately exercised,
quantitatively evaluated, and compared against a matched conventional
baseline.

No final research gap is selected at this stage.