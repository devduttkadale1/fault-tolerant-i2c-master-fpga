# Final Results and Limitations

## 1. Experimental Scope

This project evaluates the cost and behavior of adding targeted fault tolerance to a conventional FPGA-based I2C master.

The final comparison contains two RTL implementations:

- Design A: baseline I2C master
- Design B: fault-aware I2C master using the same protocol core plus F1/F2 detection, classification, containment, and recovery logic

The frozen primary fault model contains exactly two abnormal conditions:

- F1: SDA stuck LOW
- F2: implementation-defined prolonged SCL LOW / loss of progress

No F3 fault class is implemented in the final RTL.

The implemented protocol target is single-master I2C Standard-mode at a nominal 100 kHz SCL rate. Multi-controller arbitration and faster I2C modes are outside the frozen RTL experiment.

## 2. Production Fault Policy

The production configuration is:

```text
SYS_CLK_HZ             = 100,000,000
I2C_CLK_HZ             = 100,000
SDA_STUCK_LIMIT_CYCLES = 10,000
SCL_STALL_LIMIT_CYCLES = 100,000
```

These thresholds are project reliability-policy parameters. They are not maximum timeout requirements defined by the base I2C specification.

For F1, the implemented recovery mechanism performs exactly nine SCL bus-clear clocks unless F2 preempts recovery while an SCL-LOW loss-of-progress condition persists.

## 3. Functional Verification Result

The final fault-aware quantitative regression closes all committed scenarios:

- regression rows: 17
- PASS rows: 17
- FAIL rows: 0
- required fault-scenario coverage points: 28
- covered points: 28
- uncovered points: 0

The regression includes threshold-boundary behavior, false-positive avoidance, legal/non-fault SCL-LOW behavior, F1 recovery, F2 containment, F1-to-F2 interaction, and return-to-service behavior.

The practical S7 regression uses accelerated simulation settings:

```text
metrics_sys_clk_hz             = 10,000,000
metrics_i2c_clk_hz             = 1,000,000
metrics_sda_stuck_limit_cycles = 3
metrics_scl_stall_limit_cycles = 5
```

These accelerated values reduce simulation runtime and do not replace the production configuration.

## 4. Production-Threshold Latency Result

Production-threshold latency was verified separately using the real 100 MHz system-clock configuration.

| Fault | Detector elapsed latency | Manager response | Result |
|---|---:|---:|---:|
| F1 SDA stuck LOW | 9,999 cycles = 99.99 us | 10,000 cycles = 100 us | PASS |
| F2 prolonged SCL LOW | 99,999 cycles = 999.99 us | 100,000 cycles = 1 ms | PASS |

The latency convention treats the first qualifying sample as sample 1. Detection occurs on sample LIMIT, so elapsed detector latency is LIMIT-1 system-clock cycles.

## 5. Matched FPGA Implementation Methodology

The baseline and fault-aware implementations were evaluated using the same matched FPGA flow:

- Vivado 2024.1
- Xilinx Artix-7 XC7A35T-1CPG236C
- Vivado part xc7a35tcpg236-1
- 10.000 ns / 100 MHz system-clock constraint
- matched synthesis, optimization, placement, routing, timing-report, and vectorless-power methodology

The comparison therefore isolates the implementation impact of the added F1/F2 fault-tolerance mechanisms under the selected flow.

## 6. Matched FPGA PPA Results

| Metric | Baseline | Fault-aware | Change |
|---|---:|---:|---:|
| Post-synth LUTs | 87 | 223 | +156.32% |
| Post-route LUTs | 86 | 219 | +154.65% |
| Post-route FFs | 66 | 144 | +118.18% |
| LUTRAM | 0 | 0 | unchanged |
| SRL | 0 | 0 | unchanged |
| RAMB36 | 0 | 0 | unchanged |
| RAMB18 | 0 | 0 | unchanged |
| DSP | 0 | 0 | unchanged |
| BUFG | 1 | 1 | unchanged |
| Post-route WNS | +5.132 ns | +4.703 ns | -0.429 ns |
| Post-route TNS | 0.000 ns | 0.000 ns | unchanged |
| Failing setup endpoints | 0 | 0 | unchanged |
| Routing errors | 0 | 0 | unchanged |
| Inferred critical-path delay | 4.868 ns | 5.297 ns | +0.429 ns |
| Indicative implementation Fmax | 205.42 MHz | 188.79 MHz | -8.10% |
| Vectorless total power | 0.072 W | 0.075 W | +4.17% |
| Vectorless dynamic power | 0.002 W | 0.005 W | +0.003 W |
| Vectorless device-static power | 0.070 W | 0.070 W | unchanged |
| Power confidence | Low | Low | unchanged |

## 7. Engineering Interpretation

The principal cost of the F1/F2 fault-tolerance mechanisms is logic area. Post-route LUT usage increases from 86 to 219, corresponding to a 154.65% increase, while FF usage increases from 66 to 144, corresponding to a 118.18% increase.

The added monitoring, threshold counters, fault-state bookkeeping, recovery control, and containment logic do not require BRAM, DSP, LUTRAM, SRL, or an additional BUFG.

Both matched implementations remain fully routed and meet the required 100 MHz setup-timing requirement with zero failing setup endpoints. The fault-aware implementation reduces WNS from +5.132 ns to +4.703 ns, a 0.429 ns reduction in timing margin.

Using the implementation-derived relation Fmax = 1 / (10.000 ns - WNS), the indicative Fmax values are 205.42 MHz for the baseline and 188.79 MHz for the fault-aware implementation. This corresponds to an indicative reduction of 8.10%.

The Vivado post-route vectorless total-power estimate increases from 0.072 W to 0.075 W, an increase of 0.003 W or 4.17% using the rounded report values.

## 8. Result Claim Boundaries and Limitations

The following boundaries apply to every interpretation of the final results:

1. No physical FPGA board was available. The project provides simulation and Vivado implementation evidence, not physical hardware validation.
2. Timing claims refer to the required 100 MHz setup-timing requirement and committed max-delay timing evidence. No hold-signoff claim is made from the available evidence package.
3. The reported Fmax values are implementation-derived indicative estimates, not measured FPGA operating frequencies.
4. Power values are Vivado post-route vectorless power estimates, not measured hardware power.
5. Both final vectorless power reports have Low confidence.
6. The dynamic-power percentage change should not be emphasized independently because the absolute values are small, rounded to milliwatt resolution, and reported with Low confidence.
7. The F1 and F2 thresholds are project policy parameters and must not be presented as base-I2C maximum timeout requirements.
8. S7 accelerated regression settings must not be confused with the separate production-threshold latency configuration.
9. The frozen fault model contains F1 and F2 only. No F3 fault class is implemented.
10. Multi-controller arbitration is outside the frozen single-master RTL scope.
11. Faster I2C modes are outside the implemented Standard-mode scope.

## 9. Paper-Ready Result Statement

The fault-aware FPGA I2C master successfully closed all 17 quantitative regression rows and all 28 required fault-scenario coverage points for the frozen F1/F2 model. At the production 100 MHz system clock, the F1 manager responds after 10,000 cycles (100 us) and the F2 manager responds after 100,000 cycles (1 ms). In the matched Artix-7 implementation, fault tolerance increases post-route LUT usage from 86 to 219 (+154.65%) and FF usage from 66 to 144 (+118.18%). Both designs remain fully routed and satisfy the required 100 MHz setup-timing constraint, with WNS changing from +5.132 ns to +4.703 ns. The implementation-derived indicative Fmax decreases from 205.42 MHz to 188.79 MHz (-8.10%), while the Vivado post-route vectorless total-power estimate increases from 0.072 W to 0.075 W (+4.17%, Low confidence).

These results demonstrate that the implemented F1/F2 fault-detection and recovery mechanisms introduce substantial logic-area overhead while retaining positive setup-timing margin at the required operating clock. The power impact is modest in absolute terms in the matched vectorless estimates, although no physical-board power measurement was performed.

## 10. Evidence References

The principal committed evidence is preserved in:

```text
results/simulation/regression_results.csv
results/simulation/coverage_summary.csv
results/simulation/fault_aware_regression/run_metadata.txt
results/simulation/production_latency_metadata.txt
results/simulation/production_latency_results.csv
results/s8_matched_implementation_metrics.txt
results/s8_final_matched_ppa_comparison.txt
docs/reproducibility/final_reproducibility_package.md
```

The S7 quantitative and production-latency evidence is traceable to checkpoint `3f76326c444a33754ce19d71b39443cffac77346`. The final matched S8 PPA comparison is traceable to checkpoint `47402b053caf47846b2e00b224c3ab4044a33b82`.
