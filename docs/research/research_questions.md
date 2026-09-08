# Working Research Questions

> These working RQs are frozen provisionally after S2 and will be finalized after S3/S4 validation.

## WRQ1 — Detection and Discrimination

Can an FPGA I2C master reliably detect SDA-stuck-LOW and implementation-defined prolonged-SCL-LOW conditions without falsely classifying legal I2C behavior, particularly legitimate clock stretching?

## WRQ2 — SDA Recovery Effectiveness

How effectively can autonomous nine-clock bus-clear control restore operation after SDA-stuck-LOW conditions under different SDA-release scenarios?

## WRQ3 — SCL-Stall Containment

Can a configurable prolonged-SCL detector safely contain or terminate a stalled transaction and return the controller to a usable state after the external bus condition is removed?

## WRQ4 — Latency and Post-Recovery Correctness

What are the detection latency, recovery or containment latency, and post-recovery transaction-success characteristics for the supported abnormal conditions?

## WRQ5 — FPGA Implementation Cost

What incremental LUT, FF, timing/Fmax, and normal-operation latency overhead is introduced by the fault-management extension relative to a matched conventional I2C-master baseline?

## Status

These are working research questions, not final publication claims.

Their exact wording may change if S3 or S4 exposes an architectural, protocol, measurement, or verification inconsistency.
