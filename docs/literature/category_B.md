# Category B — Fault Detection, Fault Tolerance, Error Handling, and Recovery

## 1. Purpose

Category B examines literature related to fault detection, fault
tolerance, diagnostic access, recovery, communication reliability,
and fault injection.

The purpose of Category B is to challenge candidate gaps identified
after Category A.

Category A established that conventional FPGA-based I2C master
implementation is already well established. Category B therefore asks:

1. Do existing fault-tolerance works already provide mechanisms
   directly equivalent to the candidate I2C fault-management
   mechanisms?

2. Is deliberate fault injection already an established verification
   methodology?

3. Which fault-detection and recovery concepts can potentially be
   transferred to an FPGA-based I2C controller?

4. Which Category A candidate gaps remain unresolved after reviewing
   the Category B papers?

Category B must not be used to claim broad absence of prior work.
A feature marked "Not reported" means only that evidence for that
feature was not identified in the reviewed paper.

---

## 2. Evidence Classification

The following terms are used throughout this document.

### Reported

Explicitly described by the paper.

### Project interpretation

A conclusion or relevance assessment made for this research project
based on evidence in the paper.

### Not reported (NR)

The reviewed paper does not provide evidence for the feature.

"Not reported" does not mean that a feature was necessarily absent
from the implemented system.

### Candidate gap

A potentially underexplored research area that remains unresolved
within the literature reviewed so far.

A candidate gap is not a novelty claim.

---

# 3. B1 — Van Treuren et al., 2019

## 3.1 Bibliographic Information

**Paper ID:** B1

**Title:**  
How Military and Aerospace Systems Can Benefit from System Test
Access Management (STAM) Using IEEE-P2654

**Authors:**  
Bradford G. Van Treuren; Ian McIntosh; Louis Y. Ungar;
Heiko Ehrenberg

**Year:**  
2019

**Category relevance:**  
System-level diagnostics, test access, fault isolation, and
fault-injection methodology.

---

## 3.2 Research Problem

### Reported

The paper addresses limitations in system-level fault diagnosis and
maintenance of military and aerospace systems.

A major problem discussed is the occurrence of No Fault Found (NFF)
events, where equipment removed as potentially faulty cannot be
confirmed as faulty during subsequent testing.

The work proposes System Test Access Management (STAM) as a mechanism
for providing system-level access to internal test resources and
embedded instruments.

STAM attempts to coordinate access across different physical
interfaces and test-access mechanisms.

---

## 3.3 Target Interfaces and Systems

### Reported

Interfaces discussed include:

- IEEE 1149.1 / JTAG
- system-level JTAG
- IEEE 1687 instrumentation
- I2C
- SPI
- USB
- MIL-STD-1553
- ARINC 429

The paper explicitly describes I2C as one of the interfaces through
which STAM may access internal instrumentation.

It also describes an example containing an I2C Master instrument and
transformations involving commands such as:

- I2CWrite
- I2CRead
- I2CWriteRead

### Project interpretation

Although I2C is explicitly present, the paper is not an RTL
implementation of a fault-tolerant I2C master.

I2C is primarily used as a transport/test-access interface within the
STAM infrastructure.

---

## 3.4 Architecture

### Reported

STAM contains or describes functions including:

- Client Interface
- Host Interface
- Transformation Logic
- Request Sequencer
- Request Generator
- Response Generator
- STAM Access Circuit Model
- transformation algorithm handlers
- test-instrument access

Transformation logic allows commands targeting instruments behind one
interface to be translated into operations through another interface.

Examples include translating I2C directives into JTAG vectors that
stimulate an I2C Master instrument.

### Not reported for an I2C master

No I2C-specific architecture is reported for:

- protocol-fault monitoring
- SCL-low timeout detection
- excessive clock-stretch detection
- missing-ACK monitoring
- stuck-SDA monitoring
- stuck-SCL monitoring
- bus-clear control
- transaction retry
- transaction abort policy
- protocol-fault recovery FSM

---

## 3.5 Fault / Diagnostic Model

### Reported

The paper discusses system-level conditions including:

- valid failures
- false alarms
- incorrect diagnoses
- inaccurate diagnoses
- ambiguous diagnoses
- No Fault Found events
- intermittent or periodic failures
- failures dependent on environmental conditions
- cable opens or shorts
- hardware-versus-software failure ambiguity

### Project interpretation

These are primarily system-maintenance and diagnostic categories.

They should not be treated as an I2C protocol-level fault
classification.

---

## 3.6 Fault Detection and Isolation

### Reported

STAM can improve observability and controllability of internal circuit
nodes and embedded instruments.

Mechanisms discussed include:

- boundary scan
- embedded boundary scan
- Built-In Test
- Built-In Self-Test
- ATE
- non-intrusive SAMPLE operations
- internal state capture
- continuity/interconnect testing
- embedded instrumentation

The paper states that internal test resources can help determine
whether a fault exists and improve fault isolation.

### Not reported

No I2C-specific detector is described for:

- missing ACK
- unexpected NACK
- prolonged SCL LOW
- abnormal clock stretching
- SDA stuck LOW
- SCL stuck LOW
- I2C transaction timeout

---

## 3.7 Fault Injection

### Reported

The paper explicitly discusses deliberate fault injection.

A suspected fault may be injected through a secure channel using
special fault-injection logic incorporated into ASIC or FPGA
elements.

These mechanisms can be used to test software releases and verify
whether software:

- handles the error correctly
- recovers correctly
- reports the error correctly

The paper also discusses sacrificial LRUs fitted with physical
fault-injection switches and wires.

It states that similar fault-injection functions can instead be
designed into devices or FPGA logic.

### Project interpretation

This provides strong evidence that general hardware-assisted fault
injection is an existing engineering and verification methodology.

Therefore:

> General fault injection cannot itself be claimed as the research
> contribution of the FPGA I2C project.

Any future contribution involving fault injection must be narrower,
for example an I2C-specific fault model, injection mechanism,
measurement methodology, or recovery-verification framework, subject
to additional literature validation.

---

## 3.8 Recovery and Fault Tolerance

### Reported

The paper gives system-level examples where detected faulty processing
paths can be avoided and data can instead be routed through parallel
working paths.

It also discusses testing whether system software recovers correctly
from deliberately injected faults.

### Project interpretation

These are examples of system-level fault tolerance.

They are not evidence of an I2C protocol recovery mechanism.

### Not reported for I2C

No evidence was identified for:

- I2C transaction retry
- I2C abort
- I2C bus clear
- I2C recovery clocks
- I2C peripheral reset
- clock-stretch timeout recovery

---

## 3.9 Verification

### Reported

Relevant verification/test concepts include:

- BIT
- BIST
- ATE
- boundary scan
- embedded instrumentation
- non-intrusive monitoring
- deliberate fault injection
- software error-handling validation

### Not reported

The paper does not report I2C-specific:

- SystemVerilog assertions
- functional coverage
- fault coverage
- detection latency
- recovery latency
- FPGA resource overhead

---

## 3.10 Relevance to This Project

B1 is primarily methodological.

It demonstrates that:

1. general fault injection already exists;
2. FPGA/ASIC logic can deliberately create fault conditions;
3. internal observability improves diagnostic capability;
4. test-access infrastructure can include I2C.

It does not provide an RTL-level I2C fault-detection/recovery
architecture.

---

# 4. B2 — Chai et al., 2008

## 4.1 Bibliographic Information

**Paper ID:** B2

**Title:**  
Improvement of I2C Bus and RS-232 Serial Port under Complex
Electromagnetic Environment

**Authors:**  
CHAI Yan-jie; SUN Ji-yin; GAO Jing; TAO Ling-jiao;
JI Jing; BAO Fei-hu

**Year:**  
2008

**Venue:**  
2008 International Conference on Computer Science and Software
Engineering

**DOI:**  
10.1109/CSSE.2008.843

---

## 4.2 Research Problem

### Reported

The paper studies communication-speed and reliability problems in an
embedded MCU system using:

- I2C
- RS-232

For the I2C portion, the MCU writes data to an EEPROM.

EEPROM programming time creates a speed mismatch: new data can arrive
while the previous EEPROM write has not yet completed, resulting in
incorrect operation or data loss.

---

## 4.3 Experimental System

### Reported

The experimental system includes:

- P89LPC931 MCU
- CAT24WC16J EEPROM
- I2C bus
- RS-232 interface
- experimental board

The system requirement used in the experiment is a communication rate
of 9600 bps.

---

## 4.4 I2C Technique

### Reported

The CAT24WC16J supports byte-write and page-write operation.

The paper reports:

- page size: 16 bytes
- typical EEPROM programming cycle: 5 ms
- maximum stated programming/erase timing: 10 ms

Using byte-write operation, the experimental system could obtain
correct results only below approximately 2400 bps.

The proposed solution uses:

- two 16-byte buffers
- SP1
- SP2
- one active receiving buffer
- one buffer available for EEPROM page writing

When the active buffer becomes full, its contents are written to the
EEPROM using I2C page-writing mode while the other buffer becomes the
new active receive buffer.

The authors report correct operation at 9600 bps using this method.

---

## 4.5 RS-232 Technique

### Reported

A separate cycle-single-buffer mechanism is proposed for RS-232.

It uses:

- Re_length
- To_length
- interrupt-based reception
- query-based transmission
- timer-based determination of whether incoming data has stopped

The paper reports that 65,536 bytes can be transferred without errors
at 9600 bps using this mechanism.

### Important distinction

The timer belongs to the RS-232 buffering algorithm.

It is not evidence of:

- I2C transaction timeout
- SCL-low timeout
- clock-stretch timeout

---

## 4.6 Fault / Reliability Model

### Reported

The directly addressed I2C problem is:

- speed mismatch between data arrival and EEPROM write timing
- resulting data loss / incorrect data handling

The paper discusses operation under a complex electromagnetic
environment, but the implemented I2C solution is a software
buffering and scheduling technique.

### Not reported for I2C

No evidence was identified for:

- SDA stuck LOW
- SCL stuck LOW
- missing ACK
- unexpected NACK
- excessive clock stretching
- arbitration loss
- stuck-bus recovery
- I2C bus clear
- protocol-level fault classification

---

## 4.7 Detection / Monitoring

### Reported

For the I2C algorithm, software determines whether the currently
active 16-byte buffer is full.

For RS-232, software monitors receive/send counters and uses timing to
identify data-block completion.

### Project interpretation

These are data-handling and flow-management mechanisms.

They should not be classified as an I2C protocol-fault detector.

---

## 4.8 Recovery / Mitigation

### Reported

When the active I2C buffer becomes full:

1. its data is written to EEPROM using page-writing mode;
2. the second buffer becomes active;
3. incoming bytes continue to be accepted.

This prevents the EEPROM programming delay from causing the observed
data-loss problem at the required communication rate.

### Project interpretation

This is a communication buffering/data-loss mitigation technique.

It is not recovery from an abnormal I2C bus state.

---

## 4.9 Fault Injection

**Not reported.**

---

## 4.10 Performance

### Reported

The paper reports:

- I2C communication rate increased from approximately
  2400 bps to 9600 bps;
- RS-232 error-free data capacity increased from approximately
  200 bytes to 65,536 bytes;
- two 16-byte I2C buffers are used.

### Important terminology

9600 bps is an interface/data communication rate.

It must not be entered as FPGA Fmax.

### Not reported

- LUT
- FF
- FPGA area
- FPGA Fmax
- FPGA power
- I2C fault-detection latency
- I2C recovery latency

---

## 4.11 Relevance to This Project

B2 demonstrates that "communication reliability" can refer to
buffering, throughput, and data-loss prevention rather than
protocol-level fault detection and recovery.

The paper therefore helps distinguish:

- communication reliability

from:

- I2C protocol fault tolerance.

It does not provide evidence of the stuck-bus, ACK-recovery, or
clock-stretch fault-management mechanisms currently being considered
for this project.

---

# 5. B3 — Fraeman et al., 2006

## 5.1 Bibliographic Information

**Paper ID:** B3

**Title:**  
Radiation Tolerant Mixed Signal Microcontroller for Martian Surface
Applications

**Authors:**  
Martin E. Fraeman; Richard C. Meitzler; Mark N. Martin;
Wesley P. Millard; Yanyi L. Wong; Joanna D. Mellert;
Jessica N. Bowles-Martinez; Kim Strohbehn; David R. Roth

**Year:**  
2006

**Category relevance:**  
Radiation tolerance, EDAC, watchdog operation, deliberate error
injection, FPGA-assisted development, and hardware fault-tolerance
methodology.

---

## 5.2 Research Problem

### Reported

The work develops a radiation-tolerant, wide-temperature mixed-signal
microcontroller intended for Martian surface and spacecraft
applications.

The design targets approximately:

- greater than 100 krad radiation tolerance
- -125°C to +85°C operating environment

The controller is intended for distributed sensor monitoring,
engineering-data acquisition, parameter monitoring, and fault
response.

---

## 5.3 Architecture

### Reported

The RPU includes:

- 8-bit processor compatible with the Motorola 68HC11
- timers
- watchdog capability
- UART interfaces
- I2C master/slave network interface
- GPIO
- interrupt controller
- SRAM
- EEPROM
- memory EDAC
- analog peripherals

The design also contains error-logging and test logic associated with
the memory interface.

---

## 5.4 I2C / Network Capability

### Reported

The RPU uses I2C for its low-speed on-board network interface.

The paper requires the controller to:

- initiate traffic as a bus master
- respond to traffic as a bus slave

The network capability table identifies:

- approximately 100 kbps
- multimaster operation
- standards-based operation

### Important interpretation constraint

The 100-kbps value is a network design capability/requirement in the
paper.

It should not be represented as a measured FPGA I2C Fmax.

---

## 5.5 Fault Model

### Reported

The primary fault model relates to radiation and physical reliability,
including:

- single-event effects
- single-event latchup
- radiation-induced bit flips
- memory soft errors
- total ionizing dose
- temperature-dependent failures

Memory reliability includes single-bit and double-bit error
conditions.

### Not reported for I2C

No evidence was identified for:

- missing ACK
- unexpected NACK
- excessive clock stretching
- SCL-low timeout
- SDA stuck LOW
- SCL stuck LOW
- bus-clear operation
- I2C transaction timeout

---

## 5.6 EDAC Fault Detection

### Reported

The memory interface contains:

- EDAC encoding/decoding
- error logging
- testing logic

Five Hamming checkbits are generated when writing a byte.

During reads, the data and checkbits are used to:

- correct all single-bit errors;
- detect double-bit errors.

If an error is detected:

- the address is latched;
- the data is latched;
- the checkbits are latched;
- either a fixable or unfixable interrupt condition is raised.

A software service routine is expected to log the condition and
perform application-dependent corrective action.

---

## 5.7 Fault Classification

### Reported

The memory EDAC architecture distinguishes:

- fixable errors
- unfixable errors

In the described coding scheme this corresponds to:

- single-bit error correction
- double-bit error detection

### Project interpretation

This is a useful example of separating:

detection -> classification -> response

However, the fault categories are memory faults, not I2C protocol
faults.

---

## 5.8 Watchdog

### Reported

The on-chip timer capability includes watchdog timing.

The capability table explicitly states:

> reset CPU on watchdog lapse

### Project interpretation

This demonstrates a general timeout/watchdog recovery concept.

It does not establish an I2C SCL-low or clock-stretch timeout
architecture.

---

## 5.9 Deliberate Error Injection

### Reported

The memory interface contains test circuitry with associated control
registers.

These mechanisms allow values to be deliberately injected into memory
or allow error conditions to be raised.

The additional logic enables:

- testing of memory bits
- exercising the error-correction logic

### Project interpretation

This is direct evidence that controlled error injection is an
established verification methodology.

A future I2C-specific injection mechanism would therefore represent an
application of an existing methodology, not the invention of fault
injection itself.

---

## 5.10 FPGA and ASIC Implementation

### Reported

Digital logic was described using VHDL.

The design was synthesized using Synopsys Design Compiler for the
target ASIC technology.

The digital logic was also synthesized to a Xilinx Virtex FPGA for:

- real-time simulation
- development of software diagnostics

The final target implementation was an ASIC using the AMI C5F
0.5-micrometer process.

### Important qualification

The paper states that test chips for major functional blocks had been
fabricated and tested.

The complete RPU itself was still being fabricated at the time of the
paper.

Therefore it is inaccurate to state that the final complete RPU ASIC
had already undergone all the reported radiation and environmental
testing.

---

## 5.11 Hardware / Radiation Results

### Reported

Relevant reported results include:

- total transistor count: 300,528
- die size: approximately 6.25 mm x 6.25 mm
- design clock requirement: 8 MHz
- total-ionizing-dose testing using Co-60
- functional blocks surviving at least 100 krad exposure, with
  qualifications regarding EEPROM data retention
- no observed radiation-induced latchup in the reported RHBD tests
- reported SEL threshold greater than 120 MeV-cm2/mg
- resistor-coupled flip-flop SEU threshold approximately
  45 MeV-cm2/mg

### Important comparison constraint

These are ASIC/radiation implementation metrics.

They cannot be directly compared against the LUT/FF numbers from
Category A FPGA implementations.

The 8-MHz clock is not reported as an FPGA maximum operating
frequency and should not be entered in the literature matrix as Fmax.

---

## 5.12 Design Limitation

### Reported

The authors explicitly state that commercial IP used in much of the
digital logic is not inherently SEU tolerant.

A more SEU-tolerant redundant flip-flop architecture was tested and
showed stronger radiation performance.

However, the final design selected a smaller resistor-coupled
flip-flop implementation.

The authors state that the area-versus-SEU-tolerance tradeoff should
be reconsidered for future versions.

---

## 5.13 Relevance to This Project

B3 provides strong methodological evidence for:

- explicit fault detection
- fault classification
- automatic correction
- watchdog recovery
- controlled fault injection
- measurable physical fault testing
- hardware-overhead tradeoffs

However, these mechanisms primarily address:

- memory faults
- radiation faults
- device-level reliability

They do not provide evidence of protocol-level I2C fault recovery.

---

# 6. Cross-Paper Comparison

| Paper | Main System | Fault / Reliability Problem | Detection | Classification | Recovery / Mitigation | Deliberate Fault Injection | I2C Protocol-Fault Recovery | Detection Latency | Recovery Latency | FPGA-Relevant PPA |
|---|---|---|---|---|---|---|---|---|---|---|
| B1 — Van Treuren et al. | STAM/system diagnostics | NFF, false alarms, diagnostic ambiguity, hardware/software faults | BIT/BIST/boundary scan/instrumentation | System diagnostic categories | System/software intervention; parallel-path routing examples | Yes — ASIC/FPGA logic and physical switches | NR | NR | NR | NR |
| B2 — Chai et al. | MCU + I2C EEPROM + RS-232 | Speed mismatch and data loss | Buffer-state monitoring; RS-232 counters/timer | NR | Double buffering and EEPROM page writes | NR | NR | NR | NR | NR |
| B3 — Fraeman et al. | Radiation-tolerant mixed-signal MCU | SEU, SEL, memory errors, radiation effects | EDAC and watchdog mechanisms | Fixable vs. unfixable memory errors | Single-bit correction, interrupt/software action, watchdog reset | Yes — memory/error injection test logic | NR | NR | NR | ASIC metrics; FPGA used for development |

---

# 7. Challenge to Category A Candidate Gaps

## 7.1 Prolonged SCL LOW / Clock-Stretch Timeout

B2 uses a timer, but that timer belongs to the RS-232 data-handling
algorithm.

B3 contains a CPU watchdog.

Neither provides evidence of monitoring the I2C SCL line or measuring
clock-stretch duration.

B1 also does not report such a mechanism.

### Current status

**Candidate gap remains within the reviewed A+B evidence.**

The defensible statement is:

> No I2C-specific SCL-low or clock-stretch timeout mechanism was
> identified in the seven Category A+B papers reviewed so far.

This does not establish absence from the broader literature.

---

## 7.2 Missing-ACK Detection / Recovery

No Category B paper provides evidence of an I2C fault-management
architecture for:

- missing ACK
- repeated NACK
- ACK timeout
- retry policy
- transaction abort policy based on repeated ACK failure

### Current status

**Candidate gap remains within the reviewed evidence.**

---

## 7.3 Stuck-Bus Detection / Recovery

No Category B paper provides evidence of:

- SDA-stuck-LOW detection
- SCL-stuck-LOW detection
- I2C bus-clear generation
- recovery clock pulses
- protocol-level stuck-bus recovery

### Current status

**Candidate gap remains within the reviewed evidence.**

No broader absence claim is justified.

---

## 7.4 Fault-Injection Verification

B1 and B3 directly demonstrate deliberate fault/error injection.

Therefore:

**General fault injection is already established.**

The original broad candidate gap:

> fault-injection verification

must be rejected or substantially narrowed.

A remaining candidate question is:

> Whether I2C protocol/bus faults are systematically injected and
> recovery behavior quantitatively evaluated in existing controller
> verification literature.

That question requires Category D and broader literature evidence.

---

# 8. Category A + B Gap Status

| Candidate Area | Category A Evidence | Category B Evidence | Status After A+B |
|---|---|---|---|
| Conventional FPGA I2C master | Established | Not challenged | Established |
| Basic read/write/FSM implementation | Established | Not challenged | Established |
| FPGA implementation | Established | FPGA also used as development platform in B3 | Established |
| General fault tolerance | Limited A relevance | Clearly demonstrated in B1/B3 | Established methodology |
| General fault injection | Not demonstrated strongly | Explicit in B1/B3 | Established methodology |
| I2C SCL-low monitoring | NR in reviewed papers | NR | Candidate gap |
| Clock-stretch timeout handling | NR | NR for I2C | Candidate gap |
| Missing-ACK recovery policy | NR | NR | Candidate gap |
| SDA/SCL stuck-bus recovery | NR | NR | Candidate gap |
| I2C protocol-level fault injection | NR | General fault injection only | Candidate gap |
| Detection latency evaluation | NR | NR for I2C faults | Candidate gap |
| Recovery latency evaluation | NR | NR for I2C faults | Candidate gap |
| FPGA PPA overhead of I2C fault-management logic | NR | NR | Candidate gap |
| Fault-oriented I2C verification methodology | Limited | General methodology only | Candidate gap; verification-literature review required |

---

# 9. What Category B Changes

## 9.1 General Fault Injection Is Not a Research Gap

This is the strongest conclusion from Category B.

B1 explicitly discusses FPGA/ASIC fault-injection logic.

B3 contains dedicated circuitry/control registers for deliberately
creating memory/error conditions.

Therefore:

> The project must not claim fault injection itself as novel.

---

## 9.2 Fault Management Can Be Structured

B3 provides explicit evidence for a flow resembling:

fault occurrence
-> detection
-> classification
-> correction/reporting

This motivates, but does not prove, a possible architectural
separation for the future I2C design.

A project-level candidate structure could eventually resemble:

monitor
-> detect
-> classify
-> recover/report

This remains a design inference rather than a literature claim.

---

## 9.3 Fault Injection Should Be Controllable and Observable

B1 and B3 support the engineering principle that fault mechanisms can
be deliberately activated during testing so that the response can be
observed.

For the future I2C project, a candidate verification strategy could
therefore deliberately create selected bus/protocol conditions and
measure:

- detection
- classification
- transaction outcome
- recovery action
- detection latency
- recovery latency

The specific I2C fault set remains undefined until subsequent
literature/specification analysis.

---

## 9.4 Reliability Is Not the Same as Protocol Fault Tolerance

B2 demonstrates this distinction clearly.

It improves I2C-related communication behavior through buffering and
EEPROM write scheduling.

That is a valid reliability improvement.

However, the reviewed evidence does not show stuck-bus, ACK-failure,
or clock-stretch recovery.

Future literature analysis must therefore distinguish:

- communication reliability
- data-loss prevention
- physical/radiation fault tolerance
- diagnostic testability
- normal protocol error handling
- protocol-level fault detection
- protocol-level fault recovery

---

# 10. Evidence-Supported Category B Conclusions

## Supported by the three reviewed papers

- General fault tolerance is established.
- Fault detection is established.
- Fault classification is established in non-I2C contexts.
- Watchdog-based recovery is established.
- Error correction is established.
- General deliberate fault injection is established.
- FPGA/ASIC logic can incorporate deliberate fault-injection features.
- I2C can coexist within larger fault-tolerant or diagnostic systems.
- Communication reliability improvements do not necessarily imply
  protocol-level fault recovery.

## Supported only within the reviewed paper set

No evidence was identified in these three Category B papers for:

- I2C SCL-low timeout detection
- I2C clock-stretch timeout recovery
- missing-ACK recovery architecture
- stuck-SDA recovery
- stuck-SCL recovery
- I2C bus-clear controller
- I2C protocol-fault injection
- I2C fault-detection latency measurements
- I2C recovery-latency measurements

## Not supported

The Category B evidence does not justify claims such as:

- no fault-tolerant I2C controller exists
- no previous I2C bus-recovery architecture exists
- no prior I2C protocol fault injection exists
- timeout recovery is novel
- stuck-bus recovery is novel
- this project would be the first fault-tolerant FPGA I2C master

---

# 11. Category B Conclusion

Category B substantially refines the research direction.

The reviewed literature demonstrates that fault tolerance,
fault detection, watchdog recovery, error correction, and deliberate
fault injection are already established engineering techniques.

Therefore, those concepts cannot independently constitute the
research contribution.

At the same time, the three Category B papers do not provide evidence
of the specific I2C protocol/bus fault-management mechanisms being
considered in this project.

The strongest defensible conclusion after Categories A+B is therefore:

> General fault-tolerance and fault-injection methodologies are prior
> art, while I2C-specific protocol/bus fault detection, recovery,
> fault-oriented verification, latency measurement, and FPGA-overhead
> evaluation remain candidate research areas requiring further
> literature and specification validation.

No final research gap or novelty claim is made at this stage.