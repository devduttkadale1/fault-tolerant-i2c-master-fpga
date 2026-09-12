#!/usr/bin/env bash

set -u
set -o pipefail

# ================================================================
# Fault-Tolerant FPGA-Based I2C Master Controller
# Fault-Aware RTL Regression
#
# Tool:
#   Vivado / XSIM 2024.1
#
# Acceptance policy:
#   1. XVLOG must succeed.
#   2. XELAB must succeed for every test.
#   3. XSIM must return zero.
#   4. Every XSIM log must contain its explicit PASS marker.
#   5. Every XSIM log must contain "ERROR COUNT = 0".
#   6. No XSIM log may contain:
#        Error: [FAIL]
#        Fatal:
#   7. Metrics test additionally requires:
#        FALSE POSITIVE COUNT = 0
#        exactly 17 S7CSVROW records
#   8. regression_results.csv must contain 21 columns per row.
#
# XSIM exit status alone is not sufficient.
# ================================================================


# ----------------------------------------------------------------
# Paths
# ----------------------------------------------------------------

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

PROJECT_ROOT="$(
    cd "${SCRIPT_DIR}/.." &&
    pwd
)"

WORKDIR="/mnt/d/i2c_fault_aware_regression"
WORKDIR_WIN='D:\i2c_fault_aware_regression'

VIVADO_BIN_WIN='D:\Vivado_2024.1\Vivado\2024.1\bin'

RESULT_ROOT="${PROJECT_ROOT}/results/simulation"
RESULT_DIR="${RESULT_ROOT}/fault_aware_regression"
LOG_DIR="${RESULT_DIR}/logs"

CSV_OUT="${RESULT_ROOT}/regression_results.csv"

GIT_COMMIT="$(
    cd "${PROJECT_ROOT}" &&
    git rev-parse HEAD
)"


# ----------------------------------------------------------------
# RTL
# ----------------------------------------------------------------

RTL_CORE="${PROJECT_ROOT}/rtl/common/i2c_master_core.sv"
RTL_DETECTOR="${PROJECT_ROOT}/rtl/fault_aware/i2c_fault_detector.sv"
RTL_MANAGER="${PROJECT_ROOT}/rtl/fault_aware/i2c_fault_manager.sv"
RTL_WRAPPER="${PROJECT_ROOT}/rtl/fault_aware/i2c_master_fault_aware.sv"


# ----------------------------------------------------------------
# Testbenches
# ----------------------------------------------------------------

TB_DETECTOR="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_fault_detector.sv"
TB_F1="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_f1_recovery.sv"
TB_F2="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_f2_containment.sv"
TB_F12="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_f1_to_f2_preemption.sv"
TB_INTEGRATION="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_fault_aware_integration.sv"
TB_METRICS="${PROJECT_ROOT}/tb/fault_aware/tb_i2c_fault_metrics.sv"


# ----------------------------------------------------------------
# Regression definition
# ----------------------------------------------------------------

TEST_TOPS=(
    "tb_i2c_fault_detector"
    "tb_i2c_f1_recovery"
    "tb_i2c_f2_containment"
    "tb_i2c_f1_to_f2_preemption"
    "tb_i2c_fault_aware_integration"
    "tb_i2c_fault_metrics"
)

TEST_MARKERS=(
    "S6.2B FAULT DETECTOR BOUNDARY TEST : PASS"
    "S6.3B F1 RECOVERY UNIT TEST : PASS"
    "S6.3D F2 CONTAINMENT UNIT TEST : PASS"
    "S6.3E F1 TO F2 PREEMPTION UNIT TEST : PASS"
    "S6.5 FAULT-AWARE WRAPPER INTEGRATION TEST : PASS"
    "S7.4 FAULT METRICS TEST : PASS"
)

TOTAL_TESTS="${#TEST_TOPS[@]}"

PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_FAILURE_MARKERS=0


# ----------------------------------------------------------------
# Failure helper
# ----------------------------------------------------------------

fail_regression()
{
    echo
    echo "============================================"
    echo "FAULT-AWARE REGRESSION : FAIL"
    echo "$1"
    echo "============================================"
    exit 1
}


# ----------------------------------------------------------------
# Header
# ----------------------------------------------------------------

echo "============================================"
echo "FAULT-AWARE I2C MASTER REGRESSION"
echo "============================================"
echo "PROJECT ROOT : ${PROJECT_ROOT}"
echo "WORKSPACE    : ${WORKDIR}"
echo "RESULT DIR   : ${RESULT_DIR}"
echo "GIT COMMIT   : ${GIT_COMMIT}"
echo "TEST COUNT   : ${TOTAL_TESTS}"
echo "============================================"


# ----------------------------------------------------------------
# Source existence
# ----------------------------------------------------------------

echo
echo "===== SOURCE EXISTENCE GATE ====="

SOURCE_FILES=(
    "${RTL_CORE}"
    "${RTL_DETECTOR}"
    "${RTL_MANAGER}"
    "${RTL_WRAPPER}"
    "${TB_DETECTOR}"
    "${TB_F1}"
    "${TB_F2}"
    "${TB_F12}"
    "${TB_INTEGRATION}"
    "${TB_METRICS}"
)

for source_file in "${SOURCE_FILES[@]}"
do
    if [[ ! -f "${source_file}" ]]
    then
        fail_regression "Missing source file: ${source_file}"
    fi

    echo "[PASS] ${source_file}"
done


# ----------------------------------------------------------------
# Clean work/result directories
# ----------------------------------------------------------------

echo
echo "===== PREPARE CLEAN WORKSPACE ====="

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}/logs"

rm -rf "${RESULT_DIR}"
mkdir -p "${LOG_DIR}"

mkdir -p "${RESULT_ROOT}"

cp "${RTL_CORE}" \
   "${WORKDIR}/i2c_master_core.sv"

cp "${RTL_DETECTOR}" \
   "${WORKDIR}/i2c_fault_detector.sv"

cp "${RTL_MANAGER}" \
   "${WORKDIR}/i2c_fault_manager.sv"

cp "${RTL_WRAPPER}" \
   "${WORKDIR}/i2c_master_fault_aware.sv"

cp "${TB_DETECTOR}" \
   "${WORKDIR}/tb_i2c_fault_detector.sv"

cp "${TB_F1}" \
   "${WORKDIR}/tb_i2c_f1_recovery.sv"

cp "${TB_F2}" \
   "${WORKDIR}/tb_i2c_f2_containment.sv"

cp "${TB_F12}" \
   "${WORKDIR}/tb_i2c_f1_to_f2_preemption.sv"

cp "${TB_INTEGRATION}" \
   "${WORKDIR}/tb_i2c_fault_aware_integration.sv"

cp "${TB_METRICS}" \
   "${WORKDIR}/tb_i2c_fault_metrics.sv"

echo "[PASS] Fresh regression workspace prepared"


# ----------------------------------------------------------------
# XVLOG
# ----------------------------------------------------------------

echo
echo "===== XVLOG ====="

cmd.exe /c \
"cd /d ${WORKDIR_WIN} && ${VIVADO_BIN_WIN}\xvlog.bat --sv i2c_master_core.sv i2c_fault_detector.sv i2c_fault_manager.sv i2c_master_fault_aware.sv tb_i2c_fault_detector.sv tb_i2c_f1_recovery.sv tb_i2c_f2_containment.sv tb_i2c_f1_to_f2_preemption.sv tb_i2c_fault_aware_integration.sv tb_i2c_fault_metrics.sv" \
2>&1 | tee "${WORKDIR}/logs/xvlog.log"

XVLOG_RC=${PIPESTATUS[0]}

echo
echo "XVLOG EXIT CODE = ${XVLOG_RC}"

if [[ "${XVLOG_RC}" -ne 0 ]]
then
    fail_regression "XVLOG returned non-zero exit status."
fi

if grep -Eiq \
'(^|[[:space:]])error:|syntax error' \
"${WORKDIR}/logs/xvlog.log"
then
    fail_regression "XVLOG error marker detected."
fi

cp "${WORKDIR}/logs/xvlog.log" \
   "${LOG_DIR}/xvlog.log"

echo "[PASS] XVLOG"


# ----------------------------------------------------------------
# XELAB + XSIM
# ----------------------------------------------------------------

for ((i = 0; i < TOTAL_TESTS; i++))
do

    TOP="${TEST_TOPS[$i]}"
    PASS_MARKER="${TEST_MARKERS[$i]}"

    SNAPSHOT="fault_aware_reg_${i}"

    XELAB_LOG="${WORKDIR}/logs/${TOP}_xelab.log"
    XSIM_LOG="${WORKDIR}/logs/${TOP}_xsim.log"

    echo
    echo "============================================"
    echo "TEST $((i + 1))/${TOTAL_TESTS}"
    echo "TOP : ${TOP}"
    echo "============================================"


    echo
    echo "===== XELAB : ${TOP} ====="

    cmd.exe /c \
    "cd /d ${WORKDIR_WIN} && ${VIVADO_BIN_WIN}\xelab.bat ${TOP} -s ${SNAPSHOT}" \
    2>&1 | tee "${XELAB_LOG}"

    XELAB_RC=${PIPESTATUS[0]}

    echo
    echo "XELAB EXIT CODE = ${XELAB_RC}"

    if [[ "${XELAB_RC}" -ne 0 ]]
    then
        echo "[FAIL] ${TOP} XELAB"

        FAILED_TESTS=$((FAILED_TESTS + 1))

        cp "${XELAB_LOG}" \
           "${LOG_DIR}/${TOP}_xelab.log"

        continue
    fi

    echo "[PASS] ${TOP} XELAB"


    echo
    echo "===== XSIM : ${TOP} ====="

    cmd.exe /c \
    "cd /d ${WORKDIR_WIN} && ${VIVADO_BIN_WIN}\xsim.bat ${SNAPSHOT} -runall" \
    2>&1 | tee "${XSIM_LOG}"

    XSIM_RC=${PIPESTATUS[0]}

    echo
    echo "XSIM EXIT CODE = ${XSIM_RC}"


    TEST_FAILED=0


    if [[ "${XSIM_RC}" -eq 0 ]]
    then
        echo "[PASS] XSIM exit status = 0"
    else
        echo "[FAIL] XSIM exit status = ${XSIM_RC}"
        TEST_FAILED=1
    fi


    if grep -Fq \
        "${PASS_MARKER}" \
        "${XSIM_LOG}"
    then
        echo "[PASS] Explicit PASS marker found"
    else
        echo "[FAIL] Missing explicit PASS marker:"
        echo "       ${PASS_MARKER}"
        TEST_FAILED=1
    fi


    if grep -Fq \
        "ERROR COUNT = 0" \
        "${XSIM_LOG}"
    then
        echo "[PASS] ERROR COUNT = 0"
    else
        echo "[FAIL] ERROR COUNT = 0 marker missing"
        TEST_FAILED=1
    fi


    FAILURE_MARKERS=$(
        grep -Ec \
        'Error: \[FAIL\]|Fatal:' \
        "${XSIM_LOG}" ||
        true
    )

    TOTAL_FAILURE_MARKERS=$((TOTAL_FAILURE_MARKERS + FAILURE_MARKERS))

    if [[ "${FAILURE_MARKERS}" -eq 0 ]]
    then
        echo "[PASS] Failure marker count = 0"
    else
        echo "[FAIL] Failure marker count = ${FAILURE_MARKERS}"
        TEST_FAILED=1
    fi


    if [[ "${TOP}" == "tb_i2c_fault_metrics" ]]
    then

        if grep -Fq \
            "FALSE POSITIVE COUNT = 0" \
            "${XSIM_LOG}"
        then
            echo "[PASS] FALSE POSITIVE COUNT = 0"
        else
            echo "[FAIL] FALSE POSITIVE COUNT = 0 missing"
            TEST_FAILED=1
        fi


        METRIC_ROW_COUNT=$(
            grep -c '^S7CSVROW,' \
            "${XSIM_LOG}" ||
            true
        )

        echo "S7CSVROW COUNT = ${METRIC_ROW_COUNT}"

        if [[ "${METRIC_ROW_COUNT}" -eq 17 ]]
        then
            echo "[PASS] Metrics row count = 17"
        else
            echo "[FAIL] Metrics row count != 17"
            TEST_FAILED=1
        fi

    fi


    cp "${XELAB_LOG}" \
       "${LOG_DIR}/${TOP}_xelab.log"

    cp "${XSIM_LOG}" \
       "${LOG_DIR}/${TOP}_xsim.log"


    if [[ "${TEST_FAILED}" -eq 0 ]]
    then

        echo
        echo "[PASS] ${TOP}"

        PASSED_TESTS=$((PASSED_TESTS + 1))

    else

        echo
        echo "[FAIL] ${TOP}"

        FAILED_TESTS=$((FAILED_TESTS + 1))

    fi

done


# ----------------------------------------------------------------
# CSV generation
# ----------------------------------------------------------------

echo
echo "===== GENERATE MACHINE-READABLE CSV ====="

METRICS_LOG="${LOG_DIR}/tb_i2c_fault_metrics_xsim.log"

if [[ ! -f "${METRICS_LOG}" ]]
then
    fail_regression "Metrics simulation log missing."
fi


cat > "${CSV_OUT}" <<'CSV_HEADER'
test_id,design,result,fault_code,threshold_cycles,fault_onset_cycle,detect_cycle,detection_latency_cycles,recovery_start_cycle,recovery_complete_cycle,recovery_latency_cycles,first_sda_release_pulse,recovery_failed,post_recovery_pass,seed,git_commit,containment_response_latency_cycles,external_release_cycle,return_to_service_latency_cycles,false_positive_count,recovery_pulse_count
CSV_HEADER


grep '^S7CSVROW,' \
"${METRICS_LOG}" |
sed 's/^S7CSVROW,//' |
sed "s/GIT_COMMIT/${GIT_COMMIT}/g" \
>> "${CSV_OUT}"


CSV_DATA_ROWS=$(($(wc -l < "${CSV_OUT}") - 1))

echo "CSV DATA ROWS = ${CSV_DATA_ROWS}"

if [[ "${CSV_DATA_ROWS}" -ne 17 ]]
then
    fail_regression \
        "regression_results.csv does not contain exactly 17 data rows."
fi


BAD_COLUMN_ROWS=$(
    awk -F',' \
    'NR > 1 && NF != 21 { count++ } END { print count+0 }' \
    "${CSV_OUT}"
)

echo "CSV BAD-COLUMN ROWS = ${BAD_COLUMN_ROWS}"

if [[ "${BAD_COLUMN_ROWS}" -ne 0 ]]
then
    fail_regression \
        "One or more CSV rows do not contain exactly 21 columns."
fi


NON_PASS_ROWS=$(
    awk -F',' \
    'NR > 1 && $3 != "PASS" { count++ } END { print count+0 }' \
    "${CSV_OUT}"
)

echo "CSV NON-PASS ROWS = ${NON_PASS_ROWS}"

if [[ "${NON_PASS_ROWS}" -ne 0 ]]
then
    fail_regression \
        "One or more CSV evidence rows are not PASS."
fi


PLACEHOLDER_ROWS=$(
    grep -c 'GIT_COMMIT' \
    "${CSV_OUT}" ||
    true
)

echo "CSV PLACEHOLDER ROWS = ${PLACEHOLDER_ROWS}"

if [[ "${PLACEHOLDER_ROWS}" -ne 0 ]]
then
    fail_regression \
        "Git commit placeholder remains in CSV."
fi


echo "[PASS] regression_results.csv generated"


# ----------------------------------------------------------------
# Reproducibility metadata
# ----------------------------------------------------------------

cat > "${RESULT_DIR}/run_metadata.txt" <<EOF
git_commit=${GIT_COMMIT}
vivado_version=2024.1
simulator=XSIM
metrics_sys_clk_hz=10000000
metrics_i2c_clk_hz=1000000
metrics_sda_stuck_limit_cycles=3
metrics_scl_stall_limit_cycles=5
test_count=${TOTAL_TESTS}
csv_data_rows=${CSV_DATA_ROWS}
EOF


# ----------------------------------------------------------------
# Final summary
# ----------------------------------------------------------------

echo
echo "============================================"
echo "FAULT-AWARE REGRESSION SUMMARY"
echo "============================================"
echo "TESTS TOTAL           = ${TOTAL_TESTS}"
echo "TESTS PASSED          = ${PASSED_TESTS}"
echo "TESTS FAILED          = ${FAILED_TESTS}"
echo "FAILURE MARKERS       = ${TOTAL_FAILURE_MARKERS}"
echo "CSV DATA ROWS         = ${CSV_DATA_ROWS}"
echo "CSV BAD-COLUMN ROWS   = ${BAD_COLUMN_ROWS}"
echo "CSV NON-PASS ROWS     = ${NON_PASS_ROWS}"
echo "CSV PLACEHOLDER ROWS  = ${PLACEHOLDER_ROWS}"
echo "GIT COMMIT            = ${GIT_COMMIT}"
echo "============================================"


if [[ "${PASSED_TESTS}" -eq "${TOTAL_TESTS}" ]] &&
   [[ "${FAILED_TESTS}" -eq 0 ]] &&
   [[ "${TOTAL_FAILURE_MARKERS}" -eq 0 ]] &&
   [[ "${CSV_DATA_ROWS}" -eq 17 ]] &&
   [[ "${BAD_COLUMN_ROWS}" -eq 0 ]] &&
   [[ "${NON_PASS_ROWS}" -eq 0 ]] &&
   [[ "${PLACEHOLDER_ROWS}" -eq 0 ]]
then

    echo
    echo "============================================"
    echo "FAULT-AWARE REGRESSION : PASS"
    echo "TESTS PASSED = ${PASSED_TESTS}/${TOTAL_TESTS}"
    echo "FAILURE MARKERS = ${TOTAL_FAILURE_MARKERS}"
    echo "CSV DATA ROWS = ${CSV_DATA_ROWS}"
    echo "============================================"

    exit 0

else

    echo
    echo "============================================"
    echo "FAULT-AWARE REGRESSION : FAIL"
    echo "TESTS PASSED = ${PASSED_TESTS}/${TOTAL_TESTS}"
    echo "TESTS FAILED = ${FAILED_TESTS}"
    echo "FAILURE MARKERS = ${TOTAL_FAILURE_MARKERS}"
    echo "============================================"

    exit 1

fi