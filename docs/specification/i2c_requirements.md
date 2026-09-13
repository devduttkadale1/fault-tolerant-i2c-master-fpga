# I2C Requirements

## 1. Bus Signals

I2C uses two bus signals:

- **SDA** — Serial Data Line
- **SCL** — Serial Clock Line

Both signals are bidirectional and use open-drain/open-collector signaling with pull-up resistors.

---

## 2. Bus Idle

The I2C bus is considered **idle** when both SDA and SCL are HIGH.

The master should check that the bus is free before starting a new transaction.

---

## 3. START Condition

A START condition occurs when **SDA transitions from HIGH to LOW while SCL is HIGH**.

START indicates the beginning of a transaction and changes the bus from idle to busy.

---

## 4. STOP Condition

A STOP condition occurs when **SDA transitions from LOW to HIGH while SCL is HIGH**.

STOP normally terminates the current transaction and releases the bus.

---

## 5. Repeated START

A repeated START allows the master to start a new transaction without first generating a STOP.

It is commonly used when the master needs to change the direction of communication or access another operation while retaining control of the bus.

---

## 6. Addressing

I2C supports device addressing using **7-bit and 10-bit addressing**.

For the initial project baseline, **7-bit addressing** will be considered.

The address phase is followed by a **Read/Write (R/W) direction bit** and an acknowledgement from the addressed device.

---

## 7. Write Transaction

In a write transaction, the master sends data to the slave.

Typical sequence:

`START → Slave Address + Write → ACK → Data → ACK → STOP`

Data is transferred in 8-bit bytes, with an acknowledgement phase following each byte.

---

## 8. Read Transaction

In a read transaction, the slave sends data to the master.

Typical sequence:

`START → Slave Address + Read → ACK → Data → Master ACK/NACK → STOP`

The master generates ACK when it wants to continue receiving data and NACK when the final byte has been received.

---

## 9. ACK/NACK

Each transmitted byte is followed by an acknowledgement clock cycle.

- **ACK:** SDA is LOW during the acknowledgement bit.
- **NACK:** SDA remains HIGH during the acknowledgement bit.

The master must correctly detect ACK/NACK during address and write phases and generate ACK/NACK during read operations.

---

## 10. Clock Stretching

Clock stretching allows a slave to hold **SCL LOW** to temporarily delay the transaction.

The master must observe the actual SCL bus level rather than assuming that SCL becomes HIGH immediately after it is released.

For the fault-tolerant design, legitimate clock stretching must be distinguished from an abnormal or stuck SCL condition.

---

## 11. Arbitration

I2C supports multi-master operation.

During arbitration, a master monitors the actual SDA bus level while transmitting. If a master releases SDA HIGH but observes SDA LOW while SCL is HIGH, it can detect that it has lost arbitration.

Arbitration loss is legal multi-controller I2C behavior; final arbitration support depends on the frozen project scope.

---

## 12. Bus Clear

A bus-clear mechanism can be used when the I2C bus becomes stuck, particularly when SDA is held LOW.

For SDA stuck LOW, UM10204 recommends nine controller-generated SCL pulses; SCL stuck LOW requires different recovery, typically hardware reset or power cycling.

The fault-tolerant controller should distinguish between:

- SDA stuck LOW
- SCL stuck LOW
- legitimate clock stretching
- recoverable bus conditions
- non-recoverable bus conditions

---

## 13. Timing Requirements

The controller must satisfy the timing requirements of the selected I2C operating mode.

Important timing parameters include:

- **tLOW** — SCL LOW period
- **tHIGH** — SCL HIGH period
- **tHD;STA** — START hold time
- **tSU;STA** — START setup time
- **tSU;DAT** — Data setup time
- **tHD;DAT** — Data hold time
- **tSU;STO** — STOP setup time
- **tBUF** — Bus free time between STOP and START

The implemented project target is I2C Standard-mode at a nominal 100 kHz, with protocol timing evaluated through simulation and matched FPGA implementation analysis.

---

## 14. Frozen Fault-Relevant Behavior

The final implemented fault model contains exactly two primary abnormal
bus conditions:

- **F1 — SDA stuck LOW**
- **F2 — prolonged SCL LOW beyond an implementation-defined
  loss-of-progress threshold**

The production project parameters are:

```text
SYS_CLK_HZ                = 100,000,000
I2C_CLK_HZ                = 100,000
SDA_STUCK_LIMIT_CYCLES    = 10,000
SCL_STALL_LIMIT_CYCLES    = 100,000
```

At 100 MHz, the manager-response thresholds correspond to:

```text
F1 = 10,000 cycles = 100 us
F2 = 100,000 cycles = 1 ms
```

These timeout values are project reliability-policy parameters and are
not maximum timeout values mandated by the base I2C specification.

The frozen fault-handling flow is:

`Fault → Detection → Classification → Recovery/Containment → Status`

F1 uses controlled nine-clock bus-clear recovery. F2 represents
implementation-defined loss of progress and releases controller ownership
while the external SCL-LOW condition persists.

Repeated ACK/NACK outcomes are not implemented as a third fault class.
NACK remains legal protocol behavior. Multi-controller arbitration,
reset-during-transaction policy, and additional unrelated fault classes
are outside the frozen primary F1/F2 experiment.

The final F1/F2 model, recovery policy, architecture, and verification
methodology were frozen before the completed RTL verification and matched
FPGA implementation study.