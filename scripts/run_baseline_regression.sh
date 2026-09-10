#!/usr/bin/env bash

set -u
set -o pipefail

# ================================================================
# Fault-Tolerant FPGA-Based I2C Master Controller
# Baseline RTL Regression
#
# Tool:
#   Vivado / XSIM 2024.1
#
# Baseline DUT:
#   rtl/common/i2c_master_core.sv
#   rtl/baseline/i2c_master_baseline.sv
#
# Acceptance policy:
#   1. XVLOG must succeed.
#   2. XELAB must succeed for every test.
#   3. Every XSIM log must contain its explicit PASS marker.
#   4. Every XSIM log must contain "ERROR COUNT = 0".
#   5. No XSIM log may contain:
#        Error: [FAIL]
#        Fatal:
#
# NOTE:
# XSIM process exit status alone is NOT used as the simulation
# acceptance criterion because earlier project testing demonstrated
# that XSIM may return zero even when $fatal occurs.
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

WORKDIR="/mnt/d/i2c_baseline_regression"
WORKDIR_WIN='D:\i2c_baseline_regression'

VIVADO_BIN_WIN='D:\Vivado_2024.1\Vivado\2024.1\bin'


# ----------------------------------------------------------------
# Source files
# ----------------------------------------------------------------

RTL_CORE="${PROJECT_ROOT}/rtl/common/i2c_master_core.sv"
RTL_BASELINE="${PROJECT_ROOT}/rtl/baseline/i2c_master_baseline.sv"

TB_IDLE="${PROJECT_ROOT}/tb/baseline/tb_baseline_idle_busfree.sv"
TB_STRETCH="${PROJECT_ROOT}/tb/baseline/tb_baseline_start_timing_stretch.sv"
TB_ADDR="${PROJECT_ROOT}/tb/baseline/tb_baseline_address_ack_nack.sv"
TB_WRITE="${PROJECT_ROOT}/tb/baseline/tb_baseline_write_transaction.sv"
TB_READ="${PROJECT_ROOT}/tb/baseline/tb_baseline_read_transaction.sv"
TB_PATTERNS="${PROJECT_ROOT}/tb/baseline/tb_baseline_patterns_back_to_back.sv"


# ----------------------------------------------------------------
# Regression tests
# ----------------------------------------------------------------

TEST_TOPS=(
    "tb_baseline_idle_busfree"
    "tb_baseline_start_timing_stretch"
    "tb_baseline_address_ack_nack"
    "tb_baseline_write_transaction"
    "tb_baseline_read_transaction"
    "tb_baseline_patterns_back_to_back"
)

TEST_MARKERS=(
    "S5.2A IDLE/BUS-FREE REGRESSION : PASS"
    "S5.2B START/TIMING/STRETCH TEST : PASS"
    "S5.3 ADDRESS ACK/NACK TEST : PASS"
    "S5.4 WRITE TRANSACTION TEST : PASS"
    "S5.5 READ TRANSACTION TEST : PASS"
    "S5.6 PATTERN/BACK-TO-BACK TEST : PASS"
)


# ----------------------------------------------------------------
# Counters
# ----------------------------------------------------------------

TOTAL_TESTS="${#TEST_TOPS[@]}"
PASSED_TESTS=0
FAILED_TESTS=0
TOTAL_FAILURE_MARKERS=0


# ----------------------------------------------------------------
# Helper
# ----------------------------------------------------------------

fail_regression()
{
    echo
    echo "============================================"
    echo "BASELINE REGRESSION : FAIL"
    echo "$1"
    echo "============================================"
    exit 1
}


# ----------------------------------------------------------------
# Header
# ----------------------------------------------------------------

echo "============================================"
echo "BASELINE I2C MASTER REGRESSION"
echo "============================================"
echo "PROJECT ROOT : ${PROJECT_ROOT}"
echo "WORKSPACE    : ${WORKDIR}"
echo "TEST COUNT   : ${TOTAL_TESTS}"
echo "============================================"


# ----------------------------------------------------------------
# Source existence gate
# ----------------------------------------------------------------

echo
echo "===== SOURCE EXISTENCE GATE ====="

SOURCE_FILES=(
    "${RTL_CORE}"
    "${RTL_BASELINE}"
    "${TB_IDLE}"
    "${TB_STRETCH}"
    "${TB_ADDR}"
    "${TB_WRITE}"
    "${TB_READ}"
    "${TB_PATTERNS}"
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
# Fresh workspace
# ----------------------------------------------------------------

echo
echo "===== PREPARE CLEAN WORKSPACE ====="

rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}/logs"

cp "${RTL_CORE}" \
   "${WORKDIR}/i2c_master_core.sv"

cp "${RTL_BASELINE}" \
   "${WORKDIR}/i2c_master_baseline.sv"

cp "${TB_IDLE}" \
   "${WORKDIR}/tb_baseline_idle_busfree.sv"

cp "${TB_STRETCH}" \
   "${WORKDIR}/tb_baseline_start_timing_stretch.sv"

cp "${TB_ADDR}" \
   "${WORKDIR}/tb_baseline_address_ack_nack.sv"

cp "${TB_WRITE}" \
   "${WORKDIR}/tb_baseline_write_transaction.sv"

cp "${TB_READ}" \
   "${WORKDIR}/tb_baseline_read_transaction.sv"

cp "${TB_PATTERNS}" \
   "${WORKDIR}/tb_baseline_patterns_back_to_back.sv"

echo "[PASS] Fresh regression workspace prepared"


# ----------------------------------------------------------------
# XVLOG
# ----------------------------------------------------------------

echo
echo "===== XVLOG ====="

cmd.exe /c \
"cd /d ${WORKDIR_WIN} && ${VIVADO_BIN_WIN}\xvlog.bat --sv i2c_master_core.sv i2c_master_baseline.sv tb_baseline_idle_busfree.sv tb_baseline_start_timing_stretch.sv tb_baseline_address_ack_nack.sv tb_baseline_write_transaction.sv tb_baseline_read_transaction.sv tb_baseline_patterns_back_to_back.sv" \
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

echo "[PASS] XVLOG"


# ----------------------------------------------------------------
# XELAB + XSIM each test
# ----------------------------------------------------------------

for ((i = 0; i < TOTAL_TESTS; i++))
do

    TOP="${TEST_TOPS[$i]}"
    PASS_MARKER="${TEST_MARKERS[$i]}"
    SNAPSHOT="baseline_reg_${i}"

    XELAB_LOG="${WORKDIR}/logs/${TOP}_xelab.log"
    XSIM_LOG="${WORKDIR}/logs/${TOP}_xsim.log"

    echo
    echo "============================================"
    echo "TEST $((i + 1))/${TOTAL_TESTS}"
    echo "TOP : ${TOP}"
    echo "============================================"


    # ------------------------------------------------------------
    # XELAB
    # ------------------------------------------------------------

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
        continue
    fi

    echo "[PASS] ${TOP} XELAB"


    # ------------------------------------------------------------
    # XSIM
    # ------------------------------------------------------------

    echo
    echo "===== XSIM : ${TOP} ====="

    cmd.exe /c \
    "cd /d ${WORKDIR_WIN} && ${VIVADO_BIN_WIN}\xsim.bat ${SNAPSHOT} -runall" \
    2>&1 | tee "${XSIM_LOG}"

    XSIM_RC=${PIPESTATUS[0]}

    echo
    echo "XSIM EXIT CODE = ${XSIM_RC}"


    # ------------------------------------------------------------
    # Explicit marker audit
    # ------------------------------------------------------------

    TEST_FAILED=0

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


    # ------------------------------------------------------------
    # Result
    # ------------------------------------------------------------

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
# Final regression summary
# ----------------------------------------------------------------

echo
echo "============================================"
echo "BASELINE REGRESSION SUMMARY"
echo "============================================"
echo "TESTS TOTAL           = ${TOTAL_TESTS}"
echo "TESTS PASSED          = ${PASSED_TESTS}"
echo "TESTS FAILED          = ${FAILED_TESTS}"
echo "FAILURE MARKERS       = ${TOTAL_FAILURE_MARKERS}"
echo "============================================"


if [[ "${PASSED_TESTS}" -eq "${TOTAL_TESTS}" ]] &&
   [[ "${FAILED_TESTS}" -eq 0 ]] &&
   [[ "${TOTAL_FAILURE_MARKERS}" -eq 0 ]]
then

    echo
    echo "============================================"
    echo "BASELINE REGRESSION : PASS"
    echo "TESTS PASSED = ${PASSED_TESTS}/${TOTAL_TESTS}"
    echo "FAILURE MARKERS = ${TOTAL_FAILURE_MARKERS}"
    echo "============================================"

    exit 0

else

    echo
    echo "============================================"
    echo "BASELINE REGRESSION : FAIL"
    echo "TESTS PASSED = ${PASSED_TESTS}/${TOTAL_TESTS}"
    echo "TESTS FAILED = ${FAILED_TESTS}"
    echo "FAILURE MARKERS = ${TOTAL_FAILURE_MARKERS}"
    echo "============================================"

    exit 1

fi