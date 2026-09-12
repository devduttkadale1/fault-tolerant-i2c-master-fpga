`timescale 1ns/1ps

module tb_i2c_fault_metrics;

    /*
     * ================================================================
     * S7 quantitative-evidence configuration
     * ================================================================
     *
     * Accelerated verification configuration only:
     *
     *     10 MHz system clock
     *     1 MHz I2C timing
     *     F1 threshold = 3 samples
     *     F2 threshold = 5 samples
     *
     * Production defaults remain unchanged in the RTL.
     */
    localparam integer SYS_CLK_HZ = 10_000_000;
    localparam integer I2C_CLK_HZ = 1_000_000;

    localparam integer F1_LIMIT = 3;
    localparam integer F2_LIMIT = 5;

    localparam time CLK_PERIOD_NS =
        1_000_000_000 / SYS_CLK_HZ;


    /*
     * ================================================================
     * DUT interface
     * ================================================================
     */
    logic clk;
    logic rst_n;

    logic cmd_accept;

    logic core_expect_bus_free;
    logic core_waiting_for_scl_high;
    logic core_transaction_active;
    logic core_scl_drive_low;

    logic sda_in;
    logic scl_in;

    logic ext_sda_hold_low;
    logic ext_scl_hold_low;

    logic fault_abort;
    logic block_cmd_ready;
    logic fault_busy_hold;
    logic fault_done_pulse;

    logic recovery_owns_bus;
    logic recovery_sda_drive_low;
    logic recovery_scl_drive_low;

    logic       fault_active;
    logic [1:0] fault_code;
    logic       recovery_active;
    logic       recovery_failed;


    /*
     * ================================================================
     * Global verification state
     * ================================================================
     */
    integer error_count;
    integer false_positive_count;

    integer cycle_count;

    logic measure_f1;
    logic measure_f2;

    integer requested_release_pulse;

    integer fault_onset_cycle;
    integer detect_cycle;

    integer recovery_start_cycle;
    integer recovery_complete_cycle;

    integer containment_release_cycle;
    integer external_release_cycle;

    integer recovery_low_pulse_count;
    integer recovery_release_count;
    integer max_completed_pulse_count;
    integer observed_sda_release_pulse;

    integer fault_abort_count;
    integer fault_done_count;


    /*
     * ================================================================
     * DUT
     * ================================================================
     */
    i2c_fault_manager #(
        .SYS_CLK_HZ             (SYS_CLK_HZ),
        .I2C_CLK_HZ             (I2C_CLK_HZ),
        .SDA_STUCK_LIMIT_CYCLES (F1_LIMIT),
        .SCL_STALL_LIMIT_CYCLES (F2_LIMIT)
    ) dut (
        .clk                     (clk),
        .rst_n                   (rst_n),

        .cmd_accept              (cmd_accept),

        .core_expect_bus_free    (core_expect_bus_free),
        .core_waiting_for_scl_high (
            core_waiting_for_scl_high
        ),
        .core_transaction_active (
            core_transaction_active
        ),
        .core_scl_drive_low      (core_scl_drive_low),

        .sda_in                  (sda_in),
        .scl_in                  (scl_in),

        .fault_abort             (fault_abort),

        .block_cmd_ready         (block_cmd_ready),
        .fault_busy_hold         (fault_busy_hold),
        .fault_done_pulse        (fault_done_pulse),

        .recovery_owns_bus       (recovery_owns_bus),
        .recovery_sda_drive_low  (recovery_sda_drive_low),
        .recovery_scl_drive_low  (recovery_scl_drive_low),

        .fault_active            (fault_active),
        .fault_code              (fault_code),
        .recovery_active         (recovery_active),
        .recovery_failed         (recovery_failed)
    );


    /*
     * ================================================================
     * Clock
     * ================================================================
     */
    initial begin

        clk = 1'b0;

        forever #(CLK_PERIOD_NS / 2) begin
            clk = ~clk;
        end

    end


    /*
     * Positive sampling-edge number.
     *
     * After reset:
     *
     *     first active sampling edge = cycle 1
     */
    always @(posedge clk) begin

        if (!rst_n) begin
            cycle_count = 0;
        end
        else begin
            cycle_count = cycle_count + 1;
        end

    end


    /*
     * ================================================================
     * Resolved open-drain bus
     * ================================================================
     *
     * Recovery ownership excludes common-core SCL intent exactly as the
     * verified wrapper does.
     */
    always_comb begin

        sda_in =
            (
                ext_sda_hold_low ||
                (
                    recovery_owns_bus &&
                    recovery_sda_drive_low
                )
            ) ?
            1'b0 :
            1'b1;


        if (recovery_owns_bus) begin

            scl_in =
                (
                    recovery_scl_drive_low ||
                    ext_scl_hold_low
                ) ?
                1'b0 :
                1'b1;

        end
        else begin

            scl_in =
                (
                    core_scl_drive_low ||
                    ext_scl_hold_low
                ) ?
                1'b0 :
                1'b1;

        end

    end


    /*
     * ================================================================
     * Check helper
     * ================================================================
     */
    task automatic check(
        input string name,
        input logic condition
    );
        begin

            if (condition) begin

                $display(
                    "[PASS] %s",
                    name
                );

            end
            else begin

                $error(
                    "[FAIL] %s",
                    name
                );

                error_count =
                    error_count + 1;

            end

        end
    endtask


    /*
     * ================================================================
     * Machine-readable result row
     * ================================================================
     *
     * Prefix:
     *
     *     S7CSVROW,
     *
     * The later regression script will extract these rows into:
     *
     *     results/simulation/regression_results.csv
     *
     * -1 means not applicable for this test.
     *
     * GIT_COMMIT is deliberately a placeholder. The regression driver
     * will replace it with the exact repository commit used for the run.
     */
    task automatic emit_row(
        input string  test_id,
        input integer passed,
        input integer row_fault_code,
        input integer threshold_cycles,
        input integer row_fault_onset_cycle,
        input integer row_detect_cycle,
        input integer row_detection_latency_cycles,
        input integer row_recovery_start_cycle,
        input integer row_recovery_complete_cycle,
        input integer row_recovery_latency_cycles,
        input integer row_first_sda_release_pulse,
        input integer row_recovery_failed,
        input integer row_post_recovery_pass,
        input integer row_containment_response_latency,
        input integer row_external_release_cycle,
        input integer row_return_to_service_latency,
        input integer row_false_positive_count,
        input integer row_recovery_pulse_count
    );

        string result_text;

        begin

            if (passed != 0) begin
                result_text = "PASS";
            end
            else begin
                result_text = "FAIL";
            end


            $display(
                "S7CSVROW,%s,fault_aware,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,0,GIT_COMMIT,%0d,%0d,%0d,%0d,%0d",
                test_id,
                result_text,
                row_fault_code,
                threshold_cycles,
                row_fault_onset_cycle,
                row_detect_cycle,
                row_detection_latency_cycles,
                row_recovery_start_cycle,
                row_recovery_complete_cycle,
                row_recovery_latency_cycles,
                row_first_sda_release_pulse,
                row_recovery_failed,
                row_post_recovery_pass,
                row_containment_response_latency,
                row_external_release_cycle,
                row_return_to_service_latency,
                row_false_positive_count,
                row_recovery_pulse_count
            );

        end

    endtask


    /*
     * ================================================================
     * Per-case metric reset
     * ================================================================
     */
    task automatic clear_case_metrics;
        begin

            fault_onset_cycle = -1;
            detect_cycle = -1;

            recovery_start_cycle = -1;
            recovery_complete_cycle = -1;

            containment_release_cycle = -1;
            external_release_cycle = -1;

            recovery_low_pulse_count = 0;
            recovery_release_count = 0;
            max_completed_pulse_count = 0;
            observed_sda_release_pulse = 0;

            fault_abort_count = 0;
            fault_done_count = 0;

            requested_release_pulse = 0;

        end
    endtask


    /*
     * ================================================================
     * Reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            measure_f1 = 1'b0;
            measure_f2 = 1'b0;

            rst_n = 1'b0;

            cmd_accept = 1'b0;

            core_expect_bus_free = 1'b0;
            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b0;
            ext_scl_hold_low = 1'b0;

            repeat (4) begin
                @(posedge clk);
            end

            @(negedge clk);
            rst_n = 1'b1;

            repeat (2) begin
                @(posedge clk);
            end

            #1;

            clear_case_metrics();


            check(
                "RESET_FAULT_INACTIVE",
                fault_active == 1'b0
            );

            check(
                "RESET_RECOVERY_INACTIVE",
                recovery_active == 1'b0
            );

            check(
                "RESET_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "RESET_COMMAND_NOT_BLOCKED",
                block_cmd_ready == 1'b0
            );

            check(
                "RESET_RECOVERY_OWNERSHIP_RELEASED",
                recovery_owns_bus == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * Event monitors
     * ================================================================
     */
    always @(posedge fault_abort) begin

        if (rst_n) begin
            fault_abort_count =
                fault_abort_count + 1;
        end

    end


    always @(posedge fault_done_pulse) begin

        if (rst_n) begin
            fault_done_count =
                fault_done_count + 1;
        end

    end


    always @(posedge recovery_active) begin

        if (
            rst_n &&
            (measure_f1 || measure_f2) &&
            (recovery_start_cycle < 0)
        ) begin

            recovery_start_cycle =
                cycle_count;

        end

    end


    /*
     * F2 containment response is the first cycle on which recovery
     * ownership has been established with both outputs released.
     */
    always @(posedge recovery_owns_bus) begin

        if (
            rst_n &&
            measure_f2 &&
            (containment_release_cycle < 0) &&
            !recovery_sda_drive_low &&
            !recovery_scl_drive_low
        ) begin

            containment_release_cycle =
                cycle_count;

        end

    end


    /*
     * ================================================================
     * F1 recovery pulse instrumentation
     * ================================================================
     */
    always @(posedge recovery_scl_drive_low) begin

        if (
            rst_n &&
            measure_f1 &&
            recovery_owns_bus
        ) begin

            recovery_low_pulse_count =
                recovery_low_pulse_count + 1;

        end

    end


    /*
     * The externally stuck SDA is released when the selected recovery
     * LOW interval ends, matching the already-verified F1 recovery TB.
     */
    always @(negedge recovery_scl_drive_low) begin

        if (
            rst_n &&
            measure_f1 &&
            recovery_owns_bus
        ) begin

            recovery_release_count =
                recovery_release_count + 1;


            if (
                (requested_release_pulse > 0) &&
                (
                    recovery_release_count ==
                    requested_release_pulse
                )
            ) begin

                ext_sda_hold_low = 1'b0;

                $display(
                    "[INFO] METRIC SDA RELEASE ON PULSE %0d",
                    recovery_release_count
                );

            end

        end

    end


    /*
     * Completed recovery-pulse count is internal manager evidence already
     * used by the verified S6 recovery test.
     */
    always @(dut.recovery_pulse_count) begin

        if (
            rst_n &&
            measure_f1 &&
            (
                dut.recovery_pulse_count >
                max_completed_pulse_count
            )
        ) begin

            max_completed_pulse_count =
                dut.recovery_pulse_count;

        end

    end


    /*
     * Preserve first manager-recorded SDA release pulse before RM_IDLE
     * clears the internal observation.
     */
    always @(dut.sda_release_pulse) begin

        if (
            rst_n &&
            measure_f1 &&
            (dut.sda_release_pulse != 0) &&
            (observed_sda_release_pulse == 0)
        ) begin

            observed_sda_release_pulse =
                dut.sda_release_pulse;

        end

    end


    /*
     * ================================================================
     * F1 LIMIT-1
     * ================================================================
     */
    task automatic test_f1_limit_minus_1;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 LIMIT-1 ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f1 = 1'b1;

            @(negedge clk);

            core_expect_bus_free = 1'b1;
            ext_sda_hold_low = 1'b1;


            for (
                i = 1;
                i <= (F1_LIMIT - 1);
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                check(
                    $sformatf(
                        "S7_F1_LIMIT_MINUS_1_SAMPLE_%0d_NO_DETECT",
                        i
                    ),
                    dut.f1_detect_pulse == 1'b0
                );

                check(
                    $sformatf(
                        "S7_F1_LIMIT_MINUS_1_SAMPLE_%0d_NO_FAULT",
                        i
                    ),
                    fault_active == 1'b0
                );

            end


            @(negedge clk);

            ext_sda_hold_low = 1'b0;
            core_expect_bus_free = 1'b0;


            repeat (2) begin
                @(posedge clk);
            end

            #1;


            check(
                "S7_F1_LIMIT_MINUS_1_FINAL_NO_FAULT",
                fault_active == 1'b0
            );


            emit_row(
                "F1_02_LIMIT_MINUS_1",
                (error_count == errors_before),
                0,
                F1_LIMIT,
                fault_onset_cycle,
                -1,
                -1,
                -1,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );


            measure_f1 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F1 exact LIMIT
     * ================================================================
     */
    task automatic test_f1_exact_limit;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 EXACT LIMIT ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f1 = 1'b1;

            @(negedge clk);

            core_expect_bus_free = 1'b1;
            ext_sda_hold_low = 1'b1;


            for (
                i = 1;
                i <= F1_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end


                if (i < F1_LIMIT) begin

                    check(
                        $sformatf(
                            "S7_F1_EXACT_SAMPLE_%0d_NO_DETECT",
                            i
                        ),
                        dut.f1_detect_pulse == 1'b0
                    );

                end
                else begin

                    check(
                        "S7_F1_DETECT_EXACTLY_AT_LIMIT",
                        dut.f1_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            check(
                "S7_F1_DETECTION_LATENCY_LIMIT_MINUS_ONE",
                (
                    detect_cycle -
                    fault_onset_cycle
                ) ==
                (F1_LIMIT - 1)
            );


            /*
             * Manager consumes detector pulse on next system-clock edge.
             */
            @(posedge clk);
            #1;


            check(
                "S7_F1_MANAGER_LATCHES_FAULT",
                fault_active == 1'b1
            );

            check(
                "S7_F1_MANAGER_LATCHES_SDA_STUCK",
                fault_code == 2'b01
            );


            emit_row(
                "F1_03_LIMIT",
                (error_count == errors_before),
                1,
                F1_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );


            measure_f1 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F1 LIMIT+1
     * ================================================================
     */
    task automatic test_f1_limit_plus_1;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 LIMIT+1 ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f1 = 1'b1;

            @(negedge clk);

            core_expect_bus_free = 1'b1;
            ext_sda_hold_low = 1'b1;


            for (
                i = 1;
                i <= F1_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                if (i < F1_LIMIT) begin

                    check(
                        "S7_F1_LIMIT_PLUS_1_BELOW_LIMIT_NO_DETECT",
                        dut.f1_detect_pulse == 1'b0
                    );

                end
                else begin

                    check(
                        "S7_F1_LIMIT_PLUS_1_DETECTS_AT_LIMIT",
                        dut.f1_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            /*
             * This is qualifying sample LIMIT+1 in terms of fault duration.
             * Detection must already have happened at LIMIT.
             */
            @(posedge clk);
            #1;


            check(
                "S7_F1_LIMIT_PLUS_1_ALREADY_CLASSIFIED",
                fault_active &&
                (fault_code == 2'b01)
            );


            emit_row(
                "F1_04_LIMIT_PLUS_1",
                (error_count == errors_before),
                1,
                F1_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );


            measure_f1 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F1 false-positive protection:
     * SDA LOW during active protocol context must not classify as F1.
     * ================================================================
     */
    task automatic test_f1_false_positive_protocol_low;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 FALSE-POSITIVE PROTOCOL SDA LOW ====="
            );

            reset_dut();

            errors_before = error_count;

            @(negedge clk);

            core_expect_bus_free = 1'b0;
            core_transaction_active = 1'b1;

            ext_sda_hold_low = 1'b1;


            for (
                i = 0;
                i < (F1_LIMIT + 2);
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                check(
                    "S7_F1_PROTOCOL_SDA_LOW_NO_DETECT",
                    dut.f1_detect_pulse == 1'b0
                );

                check(
                    "S7_F1_PROTOCOL_SDA_LOW_NO_FAULT",
                    fault_active == 1'b0
                );

            end


            if (fault_active) begin
                false_positive_count =
                    false_positive_count + 1;
            end


            @(negedge clk);

            ext_sda_hold_low = 1'b0;
            core_transaction_active = 1'b0;


            emit_row(
                "F1_FP_NORMAL_SDA_LOW",
                (error_count == errors_before),
                0,
                F1_LIMIT,
                -1,
                -1,
                -1,
                -1,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );

        end

    endtask


    /*
     * ================================================================
     * Successful F1 recovery with selected SDA release pulse
     * ================================================================
     */
    task automatic test_f1_release(
        input integer release_pulse,
        input string test_id
    );

        integer i;
        integer guard;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 RELEASE PULSE %0d =====",
                release_pulse
            );

            reset_dut();

            errors_before = error_count;

            measure_f1 = 1'b1;
            requested_release_pulse =
                release_pulse;


            @(negedge clk);

            core_expect_bus_free = 1'b1;
            ext_sda_hold_low = 1'b1;


            /*
             * Explicitly measure detector boundary.
             */
            for (
                i = 1;
                i <= F1_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                if (i < F1_LIMIT) begin

                    check(
                        "S7_F1_RECOVERY_BELOW_LIMIT_NO_DETECT",
                        dut.f1_detect_pulse == 1'b0
                    );

                end
                else begin

                    check(
                        "S7_F1_RECOVERY_DETECT_AT_LIMIT",
                        dut.f1_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            /*
             * Wait for complete recovery + tBUF + return to service.
             */
            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01) &&
                    !recovery_active &&
                    !recovery_owns_bus &&
                    !block_cmd_ready
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "S7 F1 release %0d timed out",
                        release_pulse
                    );

                end

            end


            recovery_complete_cycle =
                cycle_count;


            check(
                "S7_F1_RELEASE_EXACTLY_NINE_LOW_PULSES",
                recovery_low_pulse_count == 9
            );

            check(
                "S7_F1_RELEASE_NINE_COMPLETED_CLOCKS",
                max_completed_pulse_count == 9
            );

            check(
                "S7_F1_RELEASE_PULSE_RECORDED",
                observed_sda_release_pulse ==
                release_pulse
            );

            check(
                "S7_F1_RELEASE_SUCCESS",
                recovery_failed == 1'b0
            );

            check(
                "S7_F1_RELEASE_SINGLE_ABORT",
                fault_abort_count == 1
            );

            check(
                "S7_F1_RELEASE_NO_DONE",
                fault_done_count == 0
            );


            emit_row(
                test_id,
                (error_count == errors_before),
                1,
                F1_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                recovery_complete_cycle,
                recovery_complete_cycle - detect_cycle,
                observed_sda_release_pulse,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                max_completed_pulse_count
            );


            measure_f1 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Failed F1 recovery
     * ================================================================
     */
    task automatic test_f1_failure;

        integer i;
        integer guard;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F1 NEVER RELEASES ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f1 = 1'b1;
            requested_release_pulse = 0;


            @(negedge clk);

            core_expect_bus_free = 1'b1;
            ext_sda_hold_low = 1'b1;


            for (
                i = 1;
                i <= F1_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                if (i == F1_LIMIT) begin

                    check(
                        "S7_F1_FAILURE_DETECT_AT_LIMIT",
                        dut.f1_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            guard = 0;

            while (!recovery_failed) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "S7 F1 failure timed out"
                    );

                end

            end


            recovery_complete_cycle =
                cycle_count;


            check(
                "S7_F1_FAILURE_EXACTLY_NINE_LOW_PULSES",
                recovery_low_pulse_count == 9
            );

            check(
                "S7_F1_FAILURE_NINE_COMPLETED_CLOCKS",
                max_completed_pulse_count == 9
            );

            check(
                "S7_F1_FAILURE_NO_RELEASE_RECORDED",
                observed_sda_release_pulse == 0
            );

            check(
                "S7_F1_FAILURE_CODE",
                fault_code == 2'b01
            );

            check(
                "S7_F1_FAILURE_COMMANDS_BLOCKED",
                block_cmd_ready == 1'b1
            );


            emit_row(
                "F1_RF_NEVER_RELEASE",
                (error_count == errors_before),
                1,
                F1_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                recovery_complete_cycle,
                recovery_complete_cycle - detect_cycle,
                0,
                1,
                0,
                -1,
                -1,
                -1,
                false_positive_count,
                max_completed_pulse_count
            );


            measure_f1 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F2 false positive: controller intentionally drives SCL LOW
     * ================================================================
     */
    task automatic test_f2_master_low_filter;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F2 MASTER-DRIVEN SCL LOW FILTER ====="
            );

            reset_dut();

            errors_before = error_count;


            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;
            core_scl_drive_low = 1'b1;


            for (
                i = 0;
                i < (F2_LIMIT + 2);
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                check(
                    "S7_F2_MASTER_LOW_NO_DETECT",
                    dut.f2_detect_pulse == 1'b0
                );

                check(
                    "S7_F2_MASTER_LOW_NO_FAULT",
                    fault_active == 1'b0
                );

            end


            if (fault_active) begin
                false_positive_count =
                    false_positive_count + 1;
            end


            @(negedge clk);

            core_waiting_for_scl_high = 1'b0;
            core_scl_drive_low = 1'b0;


            emit_row(
                "F2_FP_MASTER_LOW",
                (error_count == errors_before),
                0,
                F2_LIMIT,
                -1,
                -1,
                -1,
                -1,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );

        end

    endtask


    /*
     * ================================================================
     * F2 non-detecting external hold
     * ================================================================
     */
    task automatic test_f2_nonfault_hold(
        input integer hold_cycles,
        input string test_id
    );

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F2 NON-FAULT HOLD %0d CYCLES =====",
                hold_cycles
            );

            reset_dut();

            errors_before = error_count;

            measure_f2 = 1'b1;


            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;
            core_scl_drive_low = 1'b0;
            ext_scl_hold_low = 1'b1;


            for (
                i = 1;
                i <= hold_cycles;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                check(
                    "S7_F2_NONFAULT_HOLD_NO_DETECT",
                    dut.f2_detect_pulse == 1'b0
                );

                check(
                    "S7_F2_NONFAULT_HOLD_NO_FAULT",
                    fault_active == 1'b0
                );

            end


            @(negedge clk);

            ext_scl_hold_low = 1'b0;
            core_waiting_for_scl_high = 1'b0;


            repeat (2) begin
                @(posedge clk);
            end

            #1;


            check(
                "S7_F2_NONFAULT_HOLD_FINAL_NO_FAULT",
                fault_active == 1'b0
            );


            if (fault_active) begin
                false_positive_count =
                    false_positive_count + 1;
            end


            emit_row(
                test_id,
                (error_count == errors_before),
                0,
                F2_LIMIT,
                fault_onset_cycle,
                -1,
                -1,
                -1,
                -1,
                -1,
                0,
                0,
                -1,
                -1,
                -1,
                -1,
                false_positive_count,
                0
            );


            measure_f2 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F2 exact LIMIT
     * ================================================================
     */
    task automatic test_f2_exact_limit;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F2 EXACT LIMIT ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f2 = 1'b1;


            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;
            core_transaction_active = 1'b1;
            core_scl_drive_low = 1'b0;

            ext_scl_hold_low = 1'b1;


            for (
                i = 1;
                i <= F2_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end


                if (i < F2_LIMIT) begin

                    check(
                        "S7_F2_EXACT_BELOW_LIMIT_NO_DETECT",
                        dut.f2_detect_pulse == 1'b0
                    );

                end
                else begin

                    check(
                        "S7_F2_DETECT_EXACTLY_AT_LIMIT",
                        dut.f2_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            check(
                "S7_F2_DETECTION_LATENCY_LIMIT_MINUS_ONE",
                (
                    detect_cycle -
                    fault_onset_cycle
                ) ==
                (F2_LIMIT - 1)
            );


            /*
             * Manager consumes detector pulse now.
             */
            @(posedge clk);
            #1;


            check(
                "S7_F2_MANAGER_LATCHES_FAULT",
                fault_active == 1'b1
            );

            check(
                "S7_F2_MANAGER_LATCHES_SCL_STALL",
                fault_code == 2'b10
            );

            check(
                "S7_F2_MANAGER_OWNS_BUS",
                recovery_owns_bus == 1'b1
            );

            check(
                "S7_F2_MANAGER_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "S7_F2_MANAGER_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );


            emit_row(
                "F2_03_LIMIT",
                (error_count == errors_before),
                2,
                F2_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                -1,
                -1,
                0,
                0,
                -1,
                containment_release_cycle - detect_cycle,
                -1,
                -1,
                false_positive_count,
                0
            );


            measure_f2 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F2 LIMIT+1 + extended hold + external release + return to service
     * ================================================================
     */
    task automatic test_f2_extended_release;

        integer i;
        integer guard;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 F2 LIMIT+1 / EXTENDED HOLD / RELEASE ====="
            );

            reset_dut();

            errors_before = error_count;

            measure_f2 = 1'b1;


            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;
            core_transaction_active = 1'b1;
            core_scl_drive_low = 1'b0;

            ext_scl_hold_low = 1'b1;


            for (
                i = 1;
                i <= F2_LIMIT;
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                if (i == 1) begin
                    fault_onset_cycle =
                        cycle_count;
                end

                if (i == F2_LIMIT) begin

                    check(
                        "S7_F2_EXTENDED_DETECT_AT_LIMIT",
                        dut.f2_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            /*
             * LIMIT+1 duration: classification must already be active.
             */
            @(posedge clk);
            #1;


            check(
                "S7_F2_LIMIT_PLUS_1_ALREADY_CLASSIFIED",
                fault_active &&
                (fault_code == 2'b10)
            );


            emit_row(
                "F2_04_LIMIT_PLUS_1",
                (error_count == errors_before),
                2,
                F2_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                -1,
                -1,
                0,
                0,
                -1,
                containment_release_cycle - detect_cycle,
                -1,
                -1,
                false_positive_count,
                0
            );


            /*
             * Model core response to abort while external SCL stays LOW.
             */
            @(negedge clk);

            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;


            /*
             * Extended hold.
             */
            repeat (F2_LIMIT + 5) begin
                @(posedge clk);
            end

            #1;


            check(
                "S7_F2_EXTENDED_HOLD_RECOVERY_ACTIVE",
                recovery_active == 1'b1
            );

            check(
                "S7_F2_EXTENDED_HOLD_STILL_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "S7_F2_EXTENDED_HOLD_EXTERNAL_SCL_LOW",
                scl_in == 1'b0
            );

            check(
                "S7_F2_EXTENDED_HOLD_CONTROLLER_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "S7_F2_EXTENDED_HOLD_CONTROLLER_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );


            emit_row(
                "F2_05_EXTENDED_HOLD",
                (error_count == errors_before),
                2,
                F2_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                -1,
                -1,
                0,
                0,
                -1,
                containment_release_cycle - detect_cycle,
                -1,
                -1,
                false_positive_count,
                0
            );


            /*
             * External SCL release.
             */
            @(negedge clk);

            external_release_cycle =
                cycle_count;

            ext_scl_hold_low = 1'b0;


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b10) &&
                    !recovery_active &&
                    !recovery_owns_bus &&
                    !block_cmd_ready
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "S7 F2 return-to-service timed out"
                    );

                end

            end


            recovery_complete_cycle =
                cycle_count;


            check(
                "S7_F2_EXTERNAL_RELEASE_RETURNS_TO_SERVICE",
                !recovery_active &&
                !recovery_owns_bus &&
                !block_cmd_ready
            );

            check(
                "S7_F2_FINAL_CODE_REMAINS_SCL_STALL",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "S7_F2_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );


            emit_row(
                "F2_06_EXTERNAL_RELEASE",
                (error_count == errors_before),
                2,
                F2_LIMIT,
                fault_onset_cycle,
                detect_cycle,
                detect_cycle - fault_onset_cycle,
                recovery_start_cycle,
                recovery_complete_cycle,
                recovery_complete_cycle - detect_cycle,
                0,
                0,
                -1,
                containment_release_cycle - detect_cycle,
                external_release_cycle,
                recovery_complete_cycle - detect_cycle,
                false_positive_count,
                0
            );


            measure_f2 = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Watchdog
     * ================================================================
     */
    initial begin

        #5_000_000;

        $fatal(
            1,
            "S7.4 FAULT METRICS WATCHDOG: simulation did not finish"
        );

    end


    /*
     * ================================================================
     * Main
     * ================================================================
     */
    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        cmd_accept = 1'b0;

        core_expect_bus_free = 1'b0;
        core_waiting_for_scl_high = 1'b0;
        core_transaction_active = 1'b0;
        core_scl_drive_low = 1'b0;

        ext_sda_hold_low = 1'b0;
        ext_scl_hold_low = 1'b0;

        error_count = 0;
        false_positive_count = 0;

        cycle_count = 0;

        measure_f1 = 1'b0;
        measure_f2 = 1'b0;

        clear_case_metrics();


        /*
         * F1 boundaries / false positive.
         */
        test_f1_limit_minus_1();
        test_f1_exact_limit();
        test_f1_limit_plus_1();
        test_f1_false_positive_protocol_low();


        /*
         * F1 recovery matrix.
         */
        test_f1_release(
            1,
            "F1_R01_RELEASE_PULSE_1"
        );

        test_f1_release(
            3,
            "F1_R03_RELEASE_PULSE_3"
        );

        test_f1_release(
            5,
            "F1_R05_RELEASE_PULSE_5"
        );

        test_f1_release(
            9,
            "F1_R09_RELEASE_PULSE_9"
        );

        test_f1_failure();


        /*
         * F2 false positives / boundaries / containment.
         */
        test_f2_master_low_filter();

        test_f2_nonfault_hold(
            2,
            "F2_01_SHORT_STRETCH"
        );

        test_f2_nonfault_hold(
            F2_LIMIT - 1,
            "F2_02_LIMIT_MINUS_1"
        );

        test_f2_exact_limit();

        test_f2_extended_release();


        /*
         * Explicit false-positive coverage row.
         */
        check(
            "S7_FALSE_POSITIVE_COUNT_ZERO",
            false_positive_count == 0
        );


        emit_row(
            "FALSE_POSITIVE_SUMMARY",
            (false_positive_count == 0),
            0,
            -1,
            -1,
            -1,
            -1,
            -1,
            -1,
            -1,
            0,
            0,
            -1,
            -1,
            -1,
            -1,
            false_positive_count,
            0
        );


        $display("");
        $display(
            "============================================"
        );


        if (
            (error_count == 0) &&
            (false_positive_count == 0)
        ) begin

            $display(
                "S7.4 FAULT METRICS TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

            $display(
                "FALSE POSITIVE COUNT = 0"
            );

        end
        else begin

            $display(
                "S7.4 FAULT METRICS TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $display(
                "FALSE POSITIVE COUNT = %0d",
                false_positive_count
            );

            $fatal(
                1,
                "S7.4 quantitative metrics verification failed"
            );

        end


        $display(
            "============================================"
        );

        $finish;

    end

endmodule