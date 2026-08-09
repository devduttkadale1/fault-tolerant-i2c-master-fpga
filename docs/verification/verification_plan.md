# Verification Plan

## Normal Operation

- reset
- START
- STOP
- repeated START
- 7-bit addressing
- write
- read
- ACK
- NACK
- multiple transactions

## Timing / Protocol

- configurable SCL frequency
- clock stretching
- transaction boundaries
- back-to-back transactions

## Fault Injection

- SDA stuck LOW
- SCL stuck LOW
- missing ACK
- excessive clock stretching
- unexpected bus state
- reset during transaction

## Verification Techniques

- directed testing
- constrained-random testing
- assertions
- functional coverage
- scoreboard-based checking
- fault injection

## Research Metrics

- detection latency
- recovery latency
- recovery success rate
- false-positive rate
- LUT utilization
- FF utilization
- Fmax
- timing slack
- estimated power
