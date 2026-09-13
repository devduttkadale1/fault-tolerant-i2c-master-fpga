# =============================================================================
# Matched Vivado non-project flow
# Fault-Tolerant FPGA-Based I2C Master Controller
#
# Usage:
#
#   Source gate only:
#       tclsh run_matched_flow.tcl baseline gate
#       tclsh run_matched_flow.tcl fault_aware gate
#
#   Vivado implementation:
#       vivado -mode batch \
#              -source run_matched_flow.tcl \
#              -tclargs baseline run
#
#       vivado -mode batch \
#              -source run_matched_flow.tcl \
#              -tclargs fault_aware run
#
# IMPORTANT:
#   The baseline and fault-aware variants differ ONLY in:
#       1. top-level module
#       2. required RTL source files
#
#   FPGA part, timing constraint, synthesis, optimization, placement,
#   routing, reporting and power methodology are otherwise identical.
# =============================================================================


# -----------------------------------------------------------------------------
# Command-line arguments
# -----------------------------------------------------------------------------

if {[llength $argv] < 1 || [llength $argv] > 2} {
    puts stderr "ERROR: invalid arguments"
    puts stderr ""
    puts stderr "Usage:"
    puts stderr "  tclsh run_matched_flow.tcl <baseline|fault_aware> gate"
    puts stderr "  vivado -mode batch -source run_matched_flow.tcl -tclargs <baseline|fault_aware> run"
    exit 2
}

set variant [lindex $argv 0]

set mode "run"

if {[llength $argv] == 2} {
    set mode [lindex $argv 1]
}

if {$mode ne "gate" && $mode ne "run"} {
    puts stderr "ERROR: mode must be either 'gate' or 'run'"
    exit 2
}


# -----------------------------------------------------------------------------
# Frozen common configuration
# -----------------------------------------------------------------------------

set part_name "xc7a35tcpg236-1"
set clock_period_ns "10.000"

set script_dir [file dirname [file normalize [info script]]]
set repo_root  [file normalize [file join $script_dir "../.."]]

set xdc_file [file join $script_dir "common_100mhz.xdc"]


# -----------------------------------------------------------------------------
# Variant-specific configuration
# -----------------------------------------------------------------------------

switch -- $variant {

    "baseline" {

        set top_name "i2c_master_baseline"

        set rtl_sources [list \
            [file join $repo_root "rtl/common/i2c_master_core.sv"] \
            [file join $repo_root "rtl/baseline/i2c_master_baseline.sv"] \
        ]
    }

    "fault_aware" {

        set top_name "i2c_master_fault_aware"

        set rtl_sources [list \
            [file join $repo_root "rtl/common/i2c_master_core.sv"] \
            [file join $repo_root "rtl/fault_aware/i2c_fault_detector.sv"] \
            [file join $repo_root "rtl/fault_aware/i2c_fault_manager.sv"] \
            [file join $repo_root "rtl/fault_aware/i2c_master_fault_aware.sv"] \
        ]
    }

    default {

        puts stderr "ERROR: unknown variant '$variant'"
        puts stderr "Expected: baseline or fault_aware"
        exit 2
    }
}


# -----------------------------------------------------------------------------
# Output locations
# -----------------------------------------------------------------------------

set synthesis_dir [file join $repo_root "results/synthesis" $variant]
set timing_dir    [file join $repo_root "results/timing"    $variant]
set power_dir     [file join $repo_root "results/power"     $variant]

set post_synth_util_report \
    [file join $synthesis_dir "${variant}_post_synth_utilization.rpt"]

set post_synth_checkpoint \
    [file join $synthesis_dir "${variant}_post_synth.dcp"]

set post_route_util_report \
    [file join $synthesis_dir "${variant}_post_route_utilization.rpt"]

set route_status_report \
    [file join $timing_dir "${variant}_route_status.rpt"]

set timing_summary_report \
    [file join $timing_dir "${variant}_post_route_timing_summary.rpt"]

set power_report \
    [file join $power_dir "${variant}_post_route_vectorless_power.rpt"]

set post_route_checkpoint \
    [file join $synthesis_dir "${variant}_post_route.dcp"]


# -----------------------------------------------------------------------------
# Source existence gate
# -----------------------------------------------------------------------------

set gate_fail 0

if {![file exists $xdc_file]} {
    puts stderr "ERROR: missing XDC:"
    puts stderr "  $xdc_file"
    set gate_fail 1
}

foreach src $rtl_sources {

    if {![file exists $src]} {
        puts stderr "ERROR: missing RTL source:"
        puts stderr "  $src"
        set gate_fail 1
    }
}

if {$gate_fail} {
    puts stderr ""
    puts stderr "S8.2 SOURCE GATE : FAIL"
    exit 3
}


# -----------------------------------------------------------------------------
# Configuration audit
# -----------------------------------------------------------------------------

puts ""
puts "======================================================================"
puts "S8.2 MATCHED VIVADO FLOW CONFIGURATION"
puts "======================================================================"

puts "MODE              = $mode"
puts "VARIANT           = $variant"
puts "TOP               = $top_name"
puts "FPGA PART         = $part_name"
puts "CLOCK PERIOD      = $clock_period_ns ns"
puts "XDC               = $xdc_file"
puts "REPOSITORY ROOT   = $repo_root"

puts ""
puts "RTL SOURCES:"

foreach src $rtl_sources {
    puts "  $src"
}

puts ""
puts "OUTPUTS:"
puts "  synthesis dir   = $synthesis_dir"
puts "  timing dir      = $timing_dir"
puts "  power dir       = $power_dir"

puts ""
puts "REPORTS:"
puts "  $post_synth_util_report"
puts "  $post_route_util_report"
puts "  $route_status_report"
puts "  $timing_summary_report"
puts "  $power_report"

puts "======================================================================"
puts ""


# -----------------------------------------------------------------------------
# Gate-only mode
# -----------------------------------------------------------------------------

if {$mode eq "gate"} {

    puts "S8.2 SOURCE GATE : PASS"
    puts "No synthesis or implementation was launched."
    exit 0
}


# =============================================================================
# HEAVY VIVADO FLOW
#
# Nothing below this point executes during S8.2 source-gate mode.
# =============================================================================


# -----------------------------------------------------------------------------
# Create output directories
# -----------------------------------------------------------------------------

file mkdir $synthesis_dir
file mkdir $timing_dir
file mkdir $power_dir


# -----------------------------------------------------------------------------
# Read RTL
# -----------------------------------------------------------------------------

foreach src $rtl_sources {
    read_verilog -sv $src
}


# -----------------------------------------------------------------------------
# Read shared constraints
# -----------------------------------------------------------------------------

read_xdc $xdc_file


# -----------------------------------------------------------------------------
# Synthesis
# -----------------------------------------------------------------------------

synth_design \
    -top $top_name \
    -part $part_name

report_utilization \
    -hierarchical \
    -file $post_synth_util_report

write_checkpoint \
    -force \
    $post_synth_checkpoint


# -----------------------------------------------------------------------------
# Implementation
# -----------------------------------------------------------------------------

opt_design

place_design

route_design


# -----------------------------------------------------------------------------
# Post-route reports
# -----------------------------------------------------------------------------

report_route_status \
    -file $route_status_report

report_utilization \
    -hierarchical \
    -file $post_route_util_report

report_timing_summary \
    -delay_type max \
    -report_unconstrained \
    -max_paths 20 \
    -file $timing_summary_report


# -----------------------------------------------------------------------------
# Post-route vectorless power estimate
# -----------------------------------------------------------------------------

report_power \
    -file $power_report


# -----------------------------------------------------------------------------
# Final checkpoint
# -----------------------------------------------------------------------------

write_checkpoint \
    -force \
    $post_route_checkpoint


puts ""
puts "======================================================================"
puts "MATCHED VIVADO FLOW COMPLETE"
puts "VARIANT = $variant"
puts "TOP     = $top_name"
puts "PART    = $part_name"
puts "======================================================================"
puts ""

exit 0