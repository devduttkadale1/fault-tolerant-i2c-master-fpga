# Authoritative I2C Specification Verification

## Status

This document is a specification-verification record, not a literature-review category.

Primary authoritative source:

- NXP Semiconductors
- UM10204 — I2C-bus specification and user manual
- Revision 7.0
- 1 October 2021

The purpose is to separate:

1. Specification requirement
2. Specification recommendation
3. Specification-permitted behavior
4. Behavior not specified by base I2C
5. Project-specific implementation policy
6. Items requiring further interpretation

No project fault model or recovery architecture is frozen in this document.

---

## 1. Clock Stretching

### Authoritative behavior

Clock stretching is an optional I2C feature.

A target may pause a transaction by holding SCL LOW. The transaction
cannot continue until SCL is released HIGH.

A controller only needs to support clock stretching when targets in
the intended system may use it.

### Timeout

The base I2C protocol places no limit on how long clock stretching
may continue.

SMBus is different: it defines timeout behavior and imposes a maximum
duration for a prolonged LOW-clock condition.

### Project implication

A prolonged-SCL timeout in this project must therefore be classified
as an implementation/system reliability policy, not as a mandatory
base-I2C requirement.

The design must also avoid falsely identifying legitimate clock
stretching as a fault.

---

## 2. ACK / NACK

### Authoritative behavior

ACK is represented by SDA LOW during the acknowledgement clock.

NACK is represented by SDA HIGH during the acknowledgement clock.

NACK may occur for legitimate reasons, including:

- no receiver responding at the transmitted address;
- receiver temporarily unable to communicate;
- unsupported data or command;
- receiver unable to accept additional data;
- controller-receiver intentionally terminating reception.

After NACK, a controller may generate STOP to abort the transfer or a
repeated START to begin another transfer.

### Project implication

NACK itself must not automatically be classified as a hardware fault.

Any retry limit, repeated-NACK classification, or escalation policy
would be project-specific behavior.

---

## 3. Arbitration

### Authoritative behavior

Arbitration is required for multi-controller systems.

While SCL is HIGH, each transmitting controller compares the actual
SDA level with the value it intends to transmit.

A controller loses arbitration when it attempts to transmit HIGH but
observes SDA LOW.

The losing controller turns off its SDA output driver and must restart
its transaction only after the bus becomes free.

### Project implication

Arbitration loss is legal I2C protocol behavior and should not be used
as the primary abnormal-bus fault contribution of this project.

---

## 4. Bus Clear

### SCL stuck LOW

The preferred recovery described by UM10204 is to reset the affected
I2C devices using hardware reset when available.

If hardware reset is unavailable, power cycling is recommended to
activate the devices' internal power-on reset.

### SDA stuck LOW

When SDA is stuck LOW, the controller should generate nine clock
pulses.

The device holding SDA LOW should release the line during those nine
clock pulses.

If the line is not released, hardware reset or power cycling is used
to clear the bus.

### Project implication

Autonomous SDA-stuck detection followed by controlled nine-clock
bus-clear generation is the implemented F1 recovery mechanism.

The final project uses `SDA_STUCK_LIMIT_CYCLES = 10,000` at a 100 MHz
system clock. The detector and manager behavior are verified separately,
and the F1 recovery sequence generates exactly nine SCL clocks unless F2
preempts the recovery while an SCL-LOW loss-of-progress condition is
present.

---

## 5. Bus Free, START, STOP, and Repeated START

### Bus free

When the I2C bus is free, both SDA and SCL are HIGH.

A controller may initiate a transfer only when the bus is free.

### START

A START condition is defined by SDA transitioning from HIGH to LOW
while SCL is HIGH.

After START, the bus is considered busy.

### STOP

A STOP condition is defined by SDA transitioning from LOW to HIGH
while SCL is HIGH.

The bus becomes free again after the required bus-free interval
following STOP.

### Repeated START

A repeated START allows a controller to continue communication
without first generating STOP.

The bus remains busy when repeated START is used.

For bus-state purposes, START and repeated START are functionally
equivalent except where the repeated-START distinction is
specifically relevant.

### Project implication

The baseline controller must correctly generate START, STOP, and
repeated START and must not begin a new independent transfer before
the required bus-free condition is satisfied.

Recovery logic must preserve these protocol-state rules.

---

## 6. Standard-Mode Timing Requirements

The final FPGA implementation target is Standard-mode I2C with a
nominal 100 kHz SCL rate. Faster I2C modes are outside the frozen scope.

Authoritative Standard-mode timing limits relevant to the controller
include:

| Parameter | Meaning | Standard-mode requirement |
|---|---|---:|
| fSCL | SCL clock frequency | <= 100 kHz |
| tHD;STA | START / repeated START hold time | >= 4.0 us |
| tLOW | SCL LOW period | >= 4.7 us |
| tHIGH | SCL HIGH period | >= 4.0 us |
| tSU;STA | repeated START setup time | >= 4.7 us |
| tSU;DAT | data setup time | >= 250 ns |
| tHD;DAT | data hold time | >= 0 us for I2C-bus devices |
| tSU;STO | STOP setup time | >= 4.0 us |
| tBUF | bus-free time between STOP and next START | >= 4.7 us |
| tr | SDA/SCL rise time | <= 1000 ns |
| tf | SDA/SCL fall time | <= 300 ns |

These are bus/protocol timing requirements.

The internal FPGA clock frequency, counter values, prescalers, and
exact SCL generator implementation are design choices that must be
selected so that these externally visible timing requirements are
satisfied.

---

## 7. Requirement / Policy Classification

| Topic | Classification | Current interpretation |
|---|---|---|
| START definition | Specification requirement | SDA HIGH-to-LOW while SCL HIGH |
| STOP definition | Specification requirement | SDA LOW-to-HIGH while SCL HIGH |
| Bus free | Specification behavior/requirement | SDA and SCL HIGH; timing also constrained by tBUF |
| Repeated START | Specification-permitted protocol behavior | Continues transfer without first issuing STOP |
| ACK/NACK encoding | Specification requirement | ACK = SDA LOW; NACK = SDA HIGH during ACK clock |
| NACK occurrence | Legal protocol behavior | NACK can occur for multiple legitimate reasons |
| Retry count after NACK | Project implementation policy | Base I2C does not define our retry limit |
| Clock stretching | Specification-permitted optional behavior | Target may hold SCL LOW |
| Maximum I2C clock-stretch duration | Not specified by base I2C | No base-I2C timeout limit |
| Prolonged-SCL timeout threshold | Project implementation policy | Frozen production value = 100,000 system-clock cycles (1 ms at 100 MHz); not a base-I2C maximum |
| Arbitration loss | Legal protocol behavior | Required handling in multi-controller operation |
| SDA stuck LOW bus clear | Specification recommendation | Controller should generate nine clock pulses |
| SCL stuck LOW recovery | Specification recommendation | Prefer HW reset; otherwise power cycle affected devices |
| Detection latency target | Project implementation/experimental policy | Defined and measured in the final verification evidence |
| Recovery latency target | Project implementation/experimental policy | Defined by the verification methodology and reported where applicable |

---

## 8. Frozen Project Implications

Specification verification established the boundaries used by the final
implementation.

### F1 — SDA stuck LOW

F1 is part of the frozen fault model.

The implementation uses persistent SDA LOW as the qualifying abnormal
condition and applies controlled nine-clock bus-clear recovery.

Production policy:

```text
SDA_STUCK_LIMIT_CYCLES = 10,000
```

At a 100 MHz system clock, the manager response occurs at 100 us.
The threshold is a project policy parameter; the nine-clock bus-clear
behavior is specification-grounded.

### F2 — prolonged SCL LOW

F2 is part of the frozen fault model but must remain explicitly
distinguished from legal clock stretching.

Base I2C permits clock stretching and does not define a maximum stretch
duration. Therefore the project uses an implementation-defined
loss-of-progress threshold:

```text
SCL_STALL_LIMIT_CYCLES = 100,000
```

At a 100 MHz system clock, the manager response occurs at 1 ms.

The threshold is a project reliability policy, not an I2C specification
timeout. Verification therefore includes below-limit/legal SCL-LOW cases
to prevent false classification.

### Conditions not included as F3

Repeated unsuccessful ACK/NACK outcomes are not implemented as a third
fault class.

NACK itself is legal protocol behavior. Retry exhaustion and related
transaction-policy mechanisms remain outside the frozen F1/F2 scope.

## 9. Specification Verification Conclusion

The authoritative specification check establishes several important
boundaries:

1. Legal clock stretching must not automatically be treated as a
   fault.
2. The implemented prolonged-SCL timeout threshold is project-specific policy.
3. NACK must not automatically be treated as a hardware fault.
4. Arbitration loss is legal multi-controller protocol behavior.
5. SDA-stuck-LOW recovery has an explicit nine-clock bus-clear
   recommendation.
6. SCL-stuck-LOW recovery is treated differently and points toward
   reset or power-cycle recovery.
7. START, STOP, repeated START, bus-free behavior, and Standard-mode
   timing impose constraints that the RTL must respect.

The final primary fault set is frozen to F1 (SDA stuck LOW) and F2
(implementation-defined prolonged SCL LOW).

The completed architecture, RTL verification, quantitative fault
regression, production-threshold latency study, and matched FPGA
implementation analysis all use this frozen F1/F2 scope.
