#!/usr/bin/env bash

set -u
set -o pipefail

SCRIPT_DIR="$(
    cd "$(dirname "${BASH_SOURCE[0]}")" &&
    pwd
)"

PROJECT_ROOT="$(
    cd "${SCRIPT_DIR}/.." &&
    pwd
)"

RESULT_ROOT="${PROJECT_ROOT}/results/simulation"

METRICS_CSV="${RESULT_ROOT}/regression_results.csv"

FAULT_LOG_DIR="${RESULT_ROOT}/fault_aware_regression/logs"

F12_LOG="${FAULT_LOG_DIR}/tb_i2c_f1_to_f2_preemption_xsim.log"

INTEGRATION_LOG="${FAULT_LOG_DIR}/tb_i2c_fault_aware_integration_xsim.log"

OUT="${RESULT_ROOT}/coverage_summary.csv"

GIT_COMMIT="$(
    cd "${PROJECT_ROOT}" &&
    git rev-parse HEAD
)"

COVERAGE_COUNT=0


fail()
{
    echo
    echo "============================================"
    echo "FAULT COVERAGE SUMMARY : FAIL"
    echo "$1"
    echo "============================================"
    exit 1
}


require_file()
{
    if [[ ! -f "$1" ]]
    then
        fail "Missing evidence file: $1"
    fi
}


add_csv_coverage()
{
    local coverage_id="$1"
    local test_id="$2"

    local count

    count=$(
        awk -F',' -v id="${test_id}" '
            NR > 1 &&
            $1 == id &&
            $3 == "PASS" {
                count++
            }

            END {
                print count+0
            }
        ' "${METRICS_CSV}"
    )

    if [[ "${count}" -ne 1 ]]
    then
        fail \
            "Expected one PASS CSV row for ${test_id}; found ${count}."
    fi

    printf '%s,1,regression_results.csv,CSV:%s,%s\n' \
        "${coverage_id}" \
        "${test_id}" \
        "${GIT_COMMIT}" \
        >> "${OUT}"

    COVERAGE_COUNT=$((COVERAGE_COUNT + 1))
}


add_log_coverage()
{
    local coverage_id="$1"
    local source_name="$2"
    local source_file="$3"
    local marker="$4"

    if ! grep -Fq "${marker}" "${source_file}"
    then
        fail \
            "Missing marker for ${coverage_id}: ${marker}"
    fi

    printf '%s,1,%s,%s,%s\n' \
        "${coverage_id}" \
        "${source_name}" \
        "${marker}" \
        "${GIT_COMMIT}" \
        >> "${OUT}"

    COVERAGE_COUNT=$((COVERAGE_COUNT + 1))
}


echo "============================================"
echo "FAULT-AWARE COVERAGE SUMMARY GENERATOR"
echo "============================================"
echo "PROJECT ROOT : ${PROJECT_ROOT}"
echo "GIT COMMIT   : ${GIT_COMMIT}"
echo "============================================"


echo
echo "===== EVIDENCE FILE GATE ====="

require_file "${METRICS_CSV}"
require_file "${F12_LOG}"
require_file "${INTEGRATION_LOG}"

echo "[PASS] ${METRICS_CSV}"
echo "[PASS] ${F12_LOG}"
echo "[PASS] ${INTEGRATION_LOG}"


echo
echo "===== METRICS CSV INTEGRITY ====="

CSV_ROWS=$(
    awk -F',' '
        NR > 1 {
            count++
        }

        END {
            print count+0
        }
    ' "${METRICS_CSV}"
)

NON_PASS_ROWS=$(
    awk -F',' '
        NR > 1 &&
        $3 != "PASS" {
            count++
        }

        END {
            print count+0
        }
    ' "${METRICS_CSV}"
)

BAD_COLUMN_ROWS=$(
    awk -F',' '
        NF != 21 {
            count++
        }

        END {
            print count+0
        }
    ' "${METRICS_CSV}"
)

echo "CSV DATA ROWS       = ${CSV_ROWS}"
echo "CSV NON-PASS ROWS   = ${NON_PASS_ROWS}"
echo "CSV BAD-COLUMN ROWS = ${BAD_COLUMN_ROWS}"

if [[ "${CSV_ROWS}" -ne 17 ]]
then
    fail "Expected 17 quantitative evidence rows."
fi

if [[ "${NON_PASS_ROWS}" -ne 0 ]]
then
    fail "Quantitative CSV contains a non-PASS row."
fi

if [[ "${BAD_COLUMN_ROWS}" -ne 0 ]]
then
    fail "Quantitative CSV contains a malformed row."
fi


echo
echo "===== CREATE COVERAGE SUMMARY ====="

cat > "${OUT}" <<'CSV_HEADER'
coverage_id,result,source,evidence_marker,git_commit
CSV_HEADER


# ----------------------------------------------------------------
# F1 quantitative / boundary coverage
# ----------------------------------------------------------------

add_csv_coverage \
    "F1_LIMIT_MINUS_1" \
    "F1_02_LIMIT_MINUS_1"

add_csv_coverage \
    "F1_EXACT_LIMIT" \
    "F1_03_LIMIT"

add_csv_coverage \
    "F1_LIMIT_PLUS_1" \
    "F1_04_LIMIT_PLUS_1"

add_csv_coverage \
    "F1_FALSE_POSITIVE_PROTOCOL_SDA_LOW" \
    "F1_FP_NORMAL_SDA_LOW"

add_csv_coverage \
    "F1_RELEASE_PULSE_1" \
    "F1_R01_RELEASE_PULSE_1"

add_csv_coverage \
    "F1_RELEASE_PULSE_3" \
    "F1_R03_RELEASE_PULSE_3"

add_csv_coverage \
    "F1_RELEASE_PULSE_5" \
    "F1_R05_RELEASE_PULSE_5"

add_csv_coverage \
    "F1_RELEASE_PULSE_9" \
    "F1_R09_RELEASE_PULSE_9"

add_csv_coverage \
    "F1_NEVER_RELEASE_FAILURE" \
    "F1_RF_NEVER_RELEASE"


# ----------------------------------------------------------------
# F2 quantitative / false-positive coverage
# ----------------------------------------------------------------

add_csv_coverage \
    "F2_CONTROLLER_LOW_EXCLUDED" \
    "F2_FP_MASTER_LOW"

add_csv_coverage \
    "F2_SHORT_LEGAL_STRETCH" \
    "F2_01_SHORT_STRETCH"

add_csv_coverage \
    "F2_LIMIT_MINUS_1" \
    "F2_02_LIMIT_MINUS_1"

add_csv_coverage \
    "F2_EXACT_LIMIT" \
    "F2_03_LIMIT"

add_csv_coverage \
    "F2_LIMIT_PLUS_1" \
    "F2_04_LIMIT_PLUS_1"

add_csv_coverage \
    "F2_EXTENDED_HOLD" \
    "F2_05_EXTENDED_HOLD"

add_csv_coverage \
    "F2_EXTERNAL_RELEASE" \
    "F2_06_EXTERNAL_RELEASE"

add_csv_coverage \
    "FALSE_POSITIVE_COUNT_ZERO" \
    "FALSE_POSITIVE_SUMMARY"


# ----------------------------------------------------------------
# F1 -> F2 interaction coverage
# ----------------------------------------------------------------

add_log_coverage \
    "F12_F2_EXACT_THRESHOLD" \
    "tb_i2c_f1_to_f2_preemption" \
    "${F12_LOG}" \
    "[PASS] F12_F2_DETECT_EXACTLY_AT_LIMIT"

add_log_coverage \
    "F12_RECLASSIFICATION_TO_F2" \
    "tb_i2c_f1_to_f2_preemption" \
    "${F12_LOG}" \
    "[PASS] F12_F1_REPLACED_BY_F2"

add_log_coverage \
    "F12_RETURN_TO_SERVICE" \
    "tb_i2c_f1_to_f2_preemption" \
    "${F12_LOG}" \
    "[PASS] F12_RETURN_TO_SERVICE"

add_log_coverage \
    "F12_COMPLETE_TEST_PASS" \
    "tb_i2c_f1_to_f2_preemption" \
    "${F12_LOG}" \
    "S6.3E F1 TO F2 PREEMPTION UNIT TEST : PASS"


# ----------------------------------------------------------------
# Fault-aware normal operation
# ----------------------------------------------------------------

add_log_coverage \
    "FAULT_AWARE_NORMAL_WRITE" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] NORMAL_WRITE_NO_FAULT"

add_log_coverage \
    "FAULT_AWARE_NORMAL_READ" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] NORMAL_READ_NO_FAULT"

add_log_coverage \
    "FAULT_AWARE_NORMAL_NO_ABORT" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] NORMAL_PATH_NO_ABORTS"


# ----------------------------------------------------------------
# Post-fault service restoration
# ----------------------------------------------------------------

add_log_coverage \
    "POST_F1_TRANSACTION" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] WRAPPER_F1_POST_RECOVERY_SERVICE_RESTORED"

add_log_coverage \
    "POST_F2_TRANSACTION" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] WRAPPER_F2_POST_COMMAND_STATUS_CLEARED"

add_log_coverage \
    "POST_F12_TRANSACTION" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "[PASS] WRAPPER_F12_POST_RECOVERY_STATUS_CLEARED"

add_log_coverage \
    "FAULT_AWARE_INTEGRATION_PASS" \
    "tb_i2c_fault_aware_integration" \
    "${INTEGRATION_LOG}" \
    "S6.5 FAULT-AWARE WRAPPER INTEGRATION TEST : PASS"


echo
echo "===== COVERAGE SUMMARY AUDIT ====="

TOTAL_LINES=$(wc -l < "${OUT}")
DATA_LINES=$((TOTAL_LINES - 1))

BAD_RESULT_ROWS=$(
    awk -F',' '
        NR > 1 &&
        $2 != 1 {
            count++
        }

        END {
            print count+0
        }
    ' "${OUT}"
)

BAD_COLUMN_ROWS=$(
    awk -F',' '
        NF != 5 {
            count++
        }

        END {
            print count+0
        }
    ' "${OUT}"
)

DUPLICATE_IDS=$(
    awk -F',' '
        NR > 1 {
            count[$1]++
        }

        END {
            duplicates = 0

            for (id in count) {
                if (count[id] != 1)
                    duplicates++
            }

            print duplicates+0
        }
    ' "${OUT}"
)

echo "COVERAGE DATA ROWS = ${DATA_LINES}"
echo "COVERAGE COUNT     = ${COVERAGE_COUNT}"
echo "BAD RESULT ROWS    = ${BAD_RESULT_ROWS}"
echo "BAD COLUMN ROWS    = ${BAD_COLUMN_ROWS}"
echo "DUPLICATE IDS      = ${DUPLICATE_IDS}"


if [[ "${DATA_LINES}" -ne 28 ]]
then
    fail \
        "Expected 28 machine-readable coverage rows."
fi

if [[ "${COVERAGE_COUNT}" -ne 28 ]]
then
    fail \
        "Coverage generation count mismatch."
fi

if [[ "${BAD_RESULT_ROWS}" -ne 0 ]]
then
    fail \
        "Coverage summary contains a failed coverage row."
fi

if [[ "${BAD_COLUMN_ROWS}" -ne 0 ]]
then
    fail \
        "Coverage summary contains a malformed row."
fi

if [[ "${DUPLICATE_IDS}" -ne 0 ]]
then
    fail \
        "Coverage summary contains a duplicate coverage ID."
fi


echo
echo "============================================"
echo "FAULT COVERAGE SUMMARY : PASS"
echo "COVERAGE ROWS = ${DATA_LINES}/28"
echo "============================================"