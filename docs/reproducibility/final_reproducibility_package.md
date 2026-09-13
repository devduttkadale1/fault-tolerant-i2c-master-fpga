# Final Reproducibility Package

## Scope

This document is the final reproducibility manifest for the fault-tolerant FPGA I2C master project.

The frozen experiment compares:

- Design A: conventional baseline I2C master
- Design B: the same master extended with F1/F2 fault detection and recovery

The frozen primary fault model contains exactly:

- F1: SDA stuck LOW
- F2: implementation-defined prolonged SCL LOW / loss of progress

No F3 fault class is implemented in the final RTL.

## Tool and Target Configuration

- Vivado: 2024.1
- Simulator: XSIM
- FPGA: Xilinx Artix-7 XC7A35T-1CPG236C
- Vivado part: xc7a35tcpg236-1
- Production system clock: 100 MHz
- Matched FPGA clock constraint: 10.000 ns
- Nominal I2C rate: 100 kHz Standard-mode
- Physical FPGA board validation: not performed

## Evidence Revision Traceability

- S7 quantitative regression and production-latency evidence source checkpoint: `3f76326c444a33754ce19d71b39443cffac77346`
- S8 final matched FPGA PPA comparison checkpoint: `47402b053caf47846b2e00b224c3ab4044a33b82`

These checkpoint identifiers record the revisions associated with the preserved evidence. The final repository revision may contain later documentation-only commits without changing the frozen RTL or the underlying S7/S8 result artifacts.

## Primary Reproducibility Commands

From the repository root:

```bash
bash scripts/run_baseline_regression.sh
bash scripts/run_fault_aware_regression.sh
bash scripts/generate_fault_coverage_summary.sh
```

Matched Vivado preflight:

```bash
tclsh scripts/vivado/run_matched_flow.tcl baseline gate
tclsh scripts/vivado/run_matched_flow.tcl fault_aware gate
```

Matched Vivado implementation runs:

```text
vivado -mode batch -source scripts/vivado/run_matched_flow.tcl -tclargs baseline run
vivado -mode batch -source scripts/vivado/run_matched_flow.tcl -tclargs fault_aware run
```

The Vivado implementation runs are heavy runs and are not required merely to inspect the committed final evidence.

## Production Fault Configuration

```text
SYS_CLK_HZ             = 100,000,000
nominal I2C clock      = 100,000 Hz
SDA_STUCK_LIMIT_CYCLES = 10,000
SCL_STALL_LIMIT_CYCLES = 100,000
```

At 100 MHz:

- F1 detector elapsed latency: 9,999 cycles = 99.99 us
- F1 manager response: 10,000 cycles = 100 us
- F2 detector elapsed latency: 99,999 cycles = 999.99 us
- F2 manager response: 100,000 cycles = 1 ms

The first qualifying sample is sample 1. Detection occurs on sample LIMIT, so elapsed detector latency is LIMIT-1 system-clock cycles.

F1 and F2 timeout values are project reliability-policy parameters. They are not maximum timeout requirements defined by the base I2C specification.

## Accelerated S7 Quantitative Regression Configuration

```text
metrics_sys_clk_hz             = 10,000,000
metrics_i2c_clk_hz             = 1,000,000
metrics_sda_stuck_limit_cycles = 3
metrics_scl_stall_limit_cycles = 5
```

These accelerated values exist only to keep regression runtime practical. They do not replace the production configuration.

Final quantitative S7 result:

- regression rows: 17
- PASS rows: 17
- FAIL rows: 0
- required fault-scenario coverage points: 28
- covered points: 28
- uncovered points: 0

## S7 Evidence Files

```text
results/simulation/fault_aware_regression/run_metadata.txt
results/simulation/regression_results.csv
results/simulation/coverage_summary.csv
results/simulation/production_latency_metadata.txt
results/simulation/production_latency_results.csv
```

The production latency CSV contains PASS results for both F1_PRODUCTION_THRESHOLD and F2_PRODUCTION_THRESHOLD.

## Matched S8 FPGA Implementation Configuration

Both implementations use the same Vivado 2024.1 flow, xc7a35tcpg236-1 target, 10.000 ns / 100 MHz clock constraint, synthesis flow, optimization flow, placement flow, routing flow, timing-report methodology, and vectorless power-report methodology.

Common constraint file:

```text
scripts/vivado/common_100mhz.xdc
```

Matched implementation driver:

```text
scripts/vivado/run_matched_flow.tcl
```

## Final S8 Matched Results

| Metric | Baseline | Fault-aware | Change |
|---|---:|---:|---:|
| Post-synth LUTs | 87 | 223 | +156.32% |
| Post-route LUTs | 86 | 219 | +154.65% |
| Post-route FFs | 66 | 144 | +118.18% |
| Post-route WNS | +5.132 ns | +4.703 ns | -0.429 ns |
| Post-route TNS | 0.000 ns | 0.000 ns | unchanged |
| Failing setup endpoints | 0 | 0 | unchanged |
| Routing errors | 0 | 0 | unchanged |
| Indicative implementation Fmax | 205.42 MHz | 188.79 MHz | -8.10% |
| Vectorless total power | 0.072 W | 0.075 W | +4.17% |
| Vectorless device static power | 0.070 W | 0.070 W | unchanged |
| Power confidence | Low | Low | unchanged |

No LUTRAM, SRL, RAMB36, RAMB18, or DSP resources are used by either implementation. Both use one BUFG.

## S8 Evidence Files

```text
results/s8_matched_implementation_metrics.txt
results/s8_final_matched_ppa_comparison.txt
results/power/s8_matched_vectorless_power_comparison.txt
results/synthesis/baseline/baseline_post_synth_utilization.rpt
results/synthesis/baseline/baseline_post_route_utilization.rpt
results/synthesis/fault_aware/fault_aware_post_synth_utilization.rpt
results/synthesis/fault_aware/fault_aware_post_route_utilization.rpt
results/timing/baseline/baseline_post_route_timing_summary.rpt
results/timing/baseline/baseline_route_status.rpt
results/timing/fault_aware/fault_aware_post_route_timing_summary.rpt
results/timing/fault_aware/fault_aware_route_status.rpt
results/power/baseline/baseline_post_route_vectorless_power.rpt
results/power/fault_aware/fault_aware_post_route_vectorless_power.rpt
```

## Interpretation Boundaries

1. No physical FPGA board was available. Simulation and Vivado implementation results are not physical hardware validation.
2. Timing closure claims refer to the required 100 MHz setup-timing requirement and committed max-delay timing evidence. No hold-signoff claim is made from this evidence package.
3. Reported Fmax values are implementation-derived indicative estimates, not measured FPGA operating frequencies.
4. Power values are Vivado post-route vectorless power estimates, not measured hardware power.
5. Both final vectorless power reports have Low confidence.
6. The dynamic-power percentage change should not be emphasized in isolation because the absolute values are small and rounded.
7. F1/F2 thresholds are project policy parameters, not base-I2C maximum timeout requirements.
8. The frozen fault model contains F1 and F2 only.

## Final Reproducibility Status

- baseline regression entry point: present
- fault-aware regression entry point: present
- coverage generation entry point: present
- production-threshold metadata/results: present
- accelerated-regression metadata/results: present
- matched Vivado flow and common XDC: present
- final S8 metric/comparison artifacts: present
- no-board and vectorless-power limitations: documented

This manifest summarizes existing committed scripts and evidence. It does not replace the underlying logs, CSV files, reports, RTL, or Vivado artifacts.
