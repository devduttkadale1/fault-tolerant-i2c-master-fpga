# =============================================================================
# Shared timing constraint
# Fault-Tolerant FPGA-Based I2C Master Controller
#
# Target FPGA : XC7A35T-1CPG236C
# System clock: 100 MHz
# Period      : 10.000 ns
#
# This XDC is intentionally shared by both:
#   - i2c_master_baseline
#   - i2c_master_fault_aware
#
# No board pin assignments are included because no physical-board validation
# is claimed in this project.
# =============================================================================

create_clock -name sys_clk -period 10.000 [get_ports clk]