# I2C Timing Requirements

## Scope

Initial implementation target: I2C Standard-mode.

Primary source:

- NXP Semiconductors
- UM10204 — I2C-bus specification and user manual
- Revision 7.0
- 1 October 2021

This document records externally observable I2C timing requirements.
Internal FPGA clocking and counter values are implementation choices.

## Standard-Mode Requirements

| Symbol | Parameter | Requirement |
|---|---|---:|
| fSCL | SCL frequency | <= 100 kHz |
| tHD;STA | START/repeated-START hold | >= 4.0 us |
| tLOW | SCL LOW period | >= 4.7 us |
| tHIGH | SCL HIGH period | >= 4.0 us |
| tSU;STA | repeated-START setup | >= 4.7 us |
| tSU;DAT | data setup | >= 250 ns |
| tHD;DAT | data hold | >= 0 us for I2C-bus devices |
| tSU;STO | STOP setup | >= 4.0 us |
| tBUF | STOP-to-next-START bus-free time | >= 4.7 us |
| tr | SDA/SCL rise time | <= 1000 ns |
| tf | SDA/SCL fall time | <= 300 ns |

## RTL Implications

The future SCL generator must be derived from the FPGA system clock
such that tLOW and tHIGH meet or exceed the Standard-mode minima.

START, repeated START, and STOP sequencing must separately satisfy
their setup/hold requirements.

A new transaction following STOP must respect tBUF.

Clock-stretch handling must observe the actual SCL input rather than
assuming that releasing SCL immediately makes the bus HIGH.

## Research Implications

The specification does not provide a maximum base-I2C clock-stretch
duration.

Therefore a prolonged-SCL timeout threshold, if included in the
fault-aware design, is a project-defined reliability parameter and
must not be presented as an I2C timing requirement.

Exact FPGA system-clock frequency and derived counter constants will
be frozen during the architecture/design stage.
