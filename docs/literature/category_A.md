# Category A — FPGA / RTL-Based I2C Controllers

## Overview

Category A contains IEEE papers focused primarily on the design,
implementation, and verification of I2C controllers using FPGA/RTL
technologies.

The reviewed papers mainly use FSM-based architectures to implement
standard I2C master transactions such as START, STOP, addressing,
read/write operations, and ACK/NACK handling.

The main purpose of this category is to establish the conventional
architecture and implementation baseline before investigating
fault-tolerant I2C controllers.

> **Important:** The observations below are based on the Category A
> papers analyzed so far. They are not yet sufficient to establish the
> final research gap or novelty claim.

---

## 1. Implementation of I²C Master Bus Controller on FPGA

### Bibliographic Information

- **Authors:** Bollam Eswari, N. Ponmagal, K. Preethi, S. G. Sreejeesh
- **Year:** 2013
- **Conference:** International Conference on Communication and Signal Processing
- **HDL:** Verilog
- **FPGA:** Xilinx Spartan-3AN
- **Development Board:** Spartan-3AN FPGA Design Kit
- **Synthesis Tool:** Xilinx ISE Design Suite 14.2
- **Simulation:** ModelSim 10.1c

### Architecture

The controller uses a **10-state FSM** to implement I2C read and write
operations.

The reported states include functions such as:

- Idle
- Start
- Slave address
- ACK wait
- Register address
- Data transmission
- Stop

The FPGA operates as the I2C master and communicates with an external
DS1307 RTC.

### I2C Features

| Feature | Status |
|---|---|
| 7-bit addressing | Yes |
| 10-bit addressing | Not reported |
| Read | Yes |
| Write | Yes |
| ACK | Yes |
| NACK | Yes |
| START | Yes |
| STOP | Yes |
| Repeated START | Yes |
| Clock stretching | Not reported |
| Arbitration | Not reported |
| Multi-master | Not reported |
| Bus clear/recovery | Not reported |

### Hardware Implementation

The design was implemented on a Spartan-3AN FPGA and interfaced with
a MAXIM DS1307 RTC using SDA/SCL lines and external 5.6 kΩ pull-up
resistors.

### FPGA Resources

| Resource | Reported Value |
|---|---:|
| LUT | 325 |
| Flip-Flops | 83 |
| Slices | 169 |
| I/O | 31 |
| Global Clock | 1 |

### Verification

The paper reports:

- ModelSim simulation
- FPGA implementation
- ChipScope Analyzer
- Hardware communication with DS1307 RTC

### Fault-Tolerance Relevance

No explicit fault-handling or recovery mechanism is reported for:

- Missing ACK
- SDA stuck LOW
- SCL stuck LOW
- Clock stretching timeout
- Bus recovery
- Arbitration loss

The controller therefore provides a useful **conventional FPGA I2C
master baseline** but does not report fault-tolerant operation.

### Candidate Limitation

The FSM-based controller appears primarily designed for normal
transaction sequencing. Fault detection and recovery mechanisms are not
reported.

---

## 2. Functional Verification Environment for I2C Master Controller using SystemVerilog

### Bibliographic Information

- **Authors:** M. Sukhanya, K. Gavaskar
- **Year:** 2017
- **Conference:** 2017 4th International Conference on Signal Processing,
  Communications and Networking (ICSCN-2017)
- **RTL:** Verilog
- **Verification:** SystemVerilog
- **Simulation:** Mentor Graphics Questa

### Architecture / Verification Environment

This work focuses primarily on the **verification environment** for an
I2C master controller.

The verification environment contains:

- Stimulus Generator
- Driver
- Monitor
- Scoreboard
- Interface

The work uses object-oriented SystemVerilog techniques and constrained
randomization.

### I2C Features

| Feature | Status |
|---|---|
| 7-bit addressing | Yes |
| 10-bit addressing | Not reported |
| Read | Yes |
| Write | Yes |
| ACK | Yes |
| NACK | Not reported |
| START | Yes |
| STOP | Yes |
| Repeated START | Not reported |
| Clock stretching | Not reported |
| Arbitration | Not reported |
| Multi-master | Not reported |
| Bus clear/recovery | Not reported |

### Verification Results

The reported verification results include:

- Constrained-random address/data generation
- Functional coverage: **100%**
- Code coverage: **92.38%**
- Statement coverage: **93.33%**
- Branch coverage: **90.47%**
- FSM coverage: **100%**

### Hardware / FPGA Results

FPGA implementation and hardware prototype results are not reported.

### Fault-Tolerance Relevance

The work provides a useful reference for developing a structured
SystemVerilog verification environment.

However, the reported verification focuses on normal I2C functionality.
Fault injection for conditions such as:

- Missing ACK
- SDA stuck LOW
- SCL stuck LOW
- Excessive clock stretching
- Bus recovery

is not reported.

### Candidate Limitation

The paper demonstrates strong functional/code coverage for the
considered scenarios, but fault-oriented verification is not reported.

This makes the work particularly relevant to the future verification
strategy of the proposed fault-tolerant controller.

---

## 3. Implementation I2C Controller by Using FPGA and Applied for 12 bits ADC

### Bibliographic Information

- **Authors:** Thanat Sooknuan, Itsariya Aksonkid, Maitree Thamma,
  Witchupong Wiboonjaroen
- **Year:** 2018
- **Conference:** The 18th International Symposium on Communications
  and Information Technologies (ISCIT 2018)
- **HDL:** VHDL
- **FPGA:** Xilinx Spartan-6
- **Device:** XC6SLX9-TQG144
- **Development Board:** Custom Xilinx FPGA board
- **Synthesis:** Xilinx XST
- **Simulation:** Xilinx ISIM

### Architecture

The controller uses an FSM containing states for:

- Idle
- Start
- Slave write
- ACK
- Address
- Write data
- Slave address
- Read data
- NACK
- Stop
- Hold
- Repeated START

The FPGA operates as the I2C master and communicates with an
MCP3221 12-bit ADC.

### I2C Features

| Feature | Status |
|---|---|
| 7-bit addressing | Yes |
| 10-bit addressing | Not reported |
| Read | Yes |
| Write | Yes |
| ACK | Yes |
| NACK | Yes |
| START | Yes |
| STOP | Yes |
| Repeated START | Yes |
| Clock stretching | Not reported |
| Arbitration | Not reported |
| Multi-master | Not reported |
| Bus clear/recovery | Not reported |

### Clock / Performance

The paper reports a 100 kHz clock/frequency value. A separately reported
SCL frequency, Fmax, latency, or timing slack is not reported in the
extracted analysis.

### FPGA Resources

| Resource | Reported Value |
|---|---:|
| LUT | 111 |
| Flip-Flops / DFFs | 60 |
| CLB Slices | 28 |
| BRAM | 0 |
| DSP | 0 |
| I/O | 49 |
| Global Buffer | 1 |

### Hardware Implementation

The design was tested using:

- Spartan-6 FPGA
- MCP3221 ADC
- 7-segment display
- Digital multimeter
- Digital oscilloscope

The extracted analysis reports successful ADC data acquisition and
identifies a 2 mV measurement offset.

### Fault-Tolerance Relevance

Fault handling and recovery are not reported.

In particular, the extracted analysis does not report mechanisms for:

- Stuck SDA
- Stuck SCL
- Clock stretching timeout
- Missing ACK recovery
- Bus clear

### Candidate Limitation

The reported FSM is primarily designed for normal sequential I2C
operation. Fault recovery mechanisms are not reported.

---

## 4. Prototyping of Dual Master I2C Bus Controller

### Bibliographic Information

- **Authors:** Anagha A, M. Mathurakani
- **Year:** 2016
- **Conference:** International Conference on Communication and Signal Processing
- **HDL:** VHDL
- **FPGA:** Xilinx Spartan-3A
- **Development Board:** Spartan-3A FPGA development board
- **Synthesis:** Xilinx ISE Design Suite 14.2
- **Simulation:** ModelSim SE 6.2b

### Architecture

The paper implements a **dual-master I2C controller**.

The reported FSM includes functions such as:

- Wait
- Start
- Address Arbitration
- ACK
- Read
- Write
- Stop

The architecture uses wired-AND behavior for arbitration.

### I2C Features

| Feature | Status |
|---|---|
| 7-bit addressing | Yes |
| 10-bit addressing | Not reported |
| Read | Yes |
| Write | Yes |
| ACK | Yes |
| NACK | Not reported |
| START | Yes |
| STOP | Yes |
| Repeated START | Not reported |
| Clock stretching | Not reported |
| Arbitration | Yes |
| Multi-master | Yes |
| Bus clear/recovery | Not reported |

### Arbitration

Arbitration is the main contribution of this work.

When arbitration is lost, the affected master transitions to a waiting
state until the bus becomes available.

The extracted analysis reports this as a hardware-controlled recovery
mechanism for arbitration loss.

### FPGA Resources

| Resource | Reported Value |
|---|---:|
| LUT | 104 |
| Flip-Flops | 79 |
| Slices | 66 |
| I/O | 36 |
| Global Clock | 1 |

### Hardware Implementation

The design was implemented on a Spartan-3A FPGA.

The reported hardware experiments included I2C read/write operations
and display of state/data using a 7-segment display.

### Fault-Tolerance Relevance

The paper demonstrates handling of **arbitration loss**, but the
extracted analysis does not report handling of:

- SDA stuck LOW
- SCL stuck LOW
- Missing ACK
- Excessive clock stretching
- Bus-clear recovery

### Candidate Limitation

The work addresses protocol-level multi-master arbitration but does not
report physical bus-fault recovery mechanisms.

---

# Cross-Paper Comparison

| Paper | Year | HDL | FPGA | Role | Read/Write | ACK/NACK | Repeated START | Stretching | Arbitration | Fault Recovery | Verification |
|---|---:|---|---|---|---|---|---|---|---|---|---|
| Eswari et al. | 2013 | Verilog | Spartan-3AN | Master | Yes/Yes | Yes/Yes | Yes | NR | NR | NR | Simulation + Hardware |
| Sukhanya & Gavaskar | 2017 | Verilog + SystemVerilog | NR | Master | Yes/Yes | Yes/NR | NR | NR | NR | NR | SystemVerilog verification |
| Sooknuan et al. | 2018 | VHDL | Spartan-6 | Master | Yes/Yes | Yes/Yes | Yes | NR | NR | NR | Simulation + Hardware |
| Anagha & Mathurakani | 2016 | VHDL | Spartan-3A | Dual Master | Yes/Yes | Yes/NR | NR | NR | Yes | Arbitration recovery | Simulation + Hardware |

**NR = Not Reported**

---

# FPGA Resource Comparison

| Paper | FPGA | LUT | FF | Slice | BRAM | DSP |
|---|---|---:|---:|---:|---:|---:|
| Eswari et al. | Spartan-3AN | 325 | 83 | 169 | NR | NR |
| Sukhanya & Gavaskar | NR | NR | NR | NR | NR | NR |
| Sooknuan et al. | Spartan-6 | 111 | 60 | 28 | 0 | 0 |
| Anagha & Mathurakani | Spartan-3A | 104 | 79 | 66 | NR | NR |

### PPA Comparison Note

The resource values should not be treated as directly comparable
benchmarks because the papers target different FPGA generations,
different architectures, and potentially different synthesis
conditions and top-level designs.

Fmax, timing slack, and power are not reported in the extracted
Category A results.

---

# Common Architecture Patterns

The Category A papers predominantly use FSM-based control.

A common transaction structure is:

```text
IDLE
  ↓
START
  ↓
ADDRESS
  ↓
ACK
  ↓
DATA
  ↓
ACK
  ↓
STOP