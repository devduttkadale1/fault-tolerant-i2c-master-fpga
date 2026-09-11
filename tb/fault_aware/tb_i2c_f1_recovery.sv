`timescale 1ns/1ps

module tb_i2c_f1_recovery;

    /*
     * ================================================================
     * Accelerated unit-test configuration
     * ================================================================
     *
     * The ratio produces a 5-cycle recovery half-period.
     *
     * Production defaults remain:
     *   SYS_CLK_HZ             = 100 MHz
     *   I2C_CLK_HZ             = 100 kHz
     *   SDA_STUCK_LIMIT_CYCLES = 10,000
     *   SCL_STALL_LIMIT_CYCLES = 100,000
     */
    localparam integer SYS_CLK_HZ = 10_000_000;
    localparam integer I2C_CLK_HZ = 1_000_000;

    localparam integer F1_LIMIT = 3;

    /*
     * Keep F2 deliberately far away in this F1-focused unit test.
     * F1 -> F2 preemption is verified separately in S6.3E.
     */
    localparam integer F2_LIMIT = 1_000;

    localparam integer HALF_PERIOD_CYCLES =
        SYS_CLK_HZ / (2 * I2C_CLK_HZ);

    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;

    /*
     * 10 MHz clock = 100 ns period.
     */
    localparam time CLK_PERIOD_NS =
        1_000_000_000 / SYS_CLK_HZ;

    localparam time HALF_PERIOD_NS =
        HALF_PERIOD_CYCLES * CLK_PERIOD_NS;


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

    integer error_count;

    integer recovery_low_pulse_count;
    integer recovery_release_count;

    integer observed_sda_release_pulse;
    integer max_completed_pulse_count;

    integer fault_abort_count;
    integer fault_done_count;

    integer low_timing_error_count;
    integer high_timing_error_count;

    integer release_on_pulse;

    logic timing_monitor_enable;
    logic low_interval_active;

    time low_start_time;
    time actual_high_start_time;


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
     * ================================================================
     * Resolved open-drain bus model
     * ================================================================
     *
     * The common core is intentionally not instantiated in this
     * manager unit test. During RM_IDLE its context inputs indicate
     * that it is released.
     */
    always_comb begin

        sda_in =
            (recovery_sda_drive_low || ext_sda_hold_low) ?
            1'b0 :
            1'b1;

        scl_in =
            (recovery_scl_drive_low || ext_scl_hold_low) ?
            1'b0 :
            1'b1;

    end


    /*
     * ================================================================
     * Check helper
     * ================================================================
     */
    task automatic check(
        input string check_name,
        input logic  condition
    );
        begin

            if (condition) begin

                $display(
                    "[PASS] %s",
                    check_name
                );

            end
            else begin

                $error(
                    "[FAIL] %s",
                    check_name
                );

                error_count = error_count + 1;

            end

        end
    endtask


    /*
     * ================================================================
     * Cycle helper
     * ================================================================
     */
    task automatic wait_cycles(
        input integer count
    );

        integer i;

        begin

            for (i = 0; i < count; i = i + 1) begin
                @(posedge clk);
            end

            #1;

        end

    endtask


    /*
     * ================================================================
     * Reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            timing_monitor_enable = 1'b0;

            rst_n = 1'b0;

            cmd_accept = 1'b0;

            core_expect_bus_free = 1'b0;
            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b0;
            ext_scl_hold_low = 1'b0;

            release_on_pulse = 0;

            repeat (4) begin
                @(posedge clk);
            end

            @(negedge clk);
            rst_n = 1'b1;

            repeat (2) begin
                @(posedge clk);
            end

            #1;

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
                "RESET_BUS_OWNERSHIP_RELEASED",
                recovery_owns_bus == 1'b0
            );

        end
    endtask


    /*
     * ================================================================
     * Reset measurement counters between scenarios
     * ================================================================
     */
    task automatic clear_metrics;
        begin

            recovery_low_pulse_count = 0;
            recovery_release_count = 0;

            observed_sda_release_pulse = 0;
            max_completed_pulse_count = 0;

            fault_abort_count = 0;
            fault_done_count = 0;

            low_timing_error_count = 0;
            high_timing_error_count = 0;

            low_interval_active = 1'b0;

            low_start_time = 0;
            actual_high_start_time = 0;

        end
    endtask


    /*
     * ================================================================
     * Start an SDA-stuck fault
     * ================================================================
     */
    task automatic start_f1_fault(
        input integer requested_release_pulse
    );
        begin

            clear_metrics();

            release_on_pulse = requested_release_pulse;
            timing_monitor_enable = 1'b1;

            @(negedge clk);

            /*
             * Common-core context says the controller expects a free
             * bus while actual SDA is externally stuck LOW.
             */
            core_expect_bus_free = 1'b1;

            core_waiting_for_scl_high = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b1;
            ext_scl_hold_low = 1'b0;

        end
    endtask


    /*
     * ================================================================
     * Wait for successful F1 return-to-service
     * ================================================================
     */
    task automatic wait_for_f1_success;

        integer guard;

        begin

            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01) &&
                    !recovery_active &&
                    !recovery_failed &&
                    !recovery_owns_bus &&
                    !block_cmd_ready
                )
            ) begin

                @(posedge clk);

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "Timed out waiting for successful F1 completion"
                    );

                end

            end

            #1;

        end

    endtask


    /*
     * ================================================================
     * Wait for failed F1 terminal state
     * ================================================================
     */
    task automatic wait_for_f1_failure;

        integer guard;

        begin

            guard = 0;

            while (!recovery_failed) begin

                @(posedge clk);

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "Timed out waiting for F1_FAILED"
                    );

                end

            end

            #1;

        end

    endtask


    /*
     * ================================================================
     * Recovery LOW timing + pulse count monitor
     * ================================================================
     */
    always @(posedge recovery_scl_drive_low) begin

        if (rst_n && timing_monitor_enable) begin

            recovery_low_pulse_count =
                recovery_low_pulse_count + 1;

            low_interval_active = 1'b1;
            low_start_time = $time;

        end

    end


    always @(negedge recovery_scl_drive_low) begin

        if (
            rst_n &&
            timing_monitor_enable &&
            low_interval_active
        ) begin

            recovery_release_count =
                recovery_release_count + 1;

            if (
                ($time - low_start_time) <
                HALF_PERIOD_NS
            ) begin

                low_timing_error_count =
                    low_timing_error_count + 1;

                $error(
                    "[FAIL] RECOVERY_LOW_TOO_SHORT pulse=%0d duration=%0t expected>=%0t",
                    recovery_release_count,
                    ($time - low_start_time),
                    HALF_PERIOD_NS
                );

            end
            else begin

                $display(
                    "[PASS] RECOVERY_LOW_TIMING pulse=%0d duration=%0t",
                    recovery_release_count,
                    ($time - low_start_time)
                );

            end

            low_interval_active = 1'b0;


            /*
             * Release externally stuck SDA at the requested recovery
             * pulse. The manager must nevertheless continue through
             * all nine recovery clocks.
             */
            if (
                (release_on_pulse > 0) &&
                (recovery_release_count == release_on_pulse)
            ) begin

                ext_sda_hold_low = 1'b0;

                $display(
                    "[INFO] SDA EXTERNAL RELEASE ON PULSE %0d",
                    recovery_release_count
                );

            end

        end

    end


    /*
     * ================================================================
     * Actual SCL-HIGH timing monitor
     * ================================================================
     */
    always @(posedge scl_in) begin

        if (
            rst_n &&
            timing_monitor_enable &&
            recovery_owns_bus
        ) begin

            actual_high_start_time = $time;

        end

    end


    /*
     * A change in completed recovery_pulse_count occurs only after the
     * verified HIGH interval has completed.
     */
    always @(dut.recovery_pulse_count) begin

        if (
            rst_n &&
            timing_monitor_enable &&
            (dut.recovery_pulse_count > 0)
        ) begin

            if (
                dut.recovery_pulse_count >
                max_completed_pulse_count
            ) begin

                max_completed_pulse_count =
                    dut.recovery_pulse_count;

                if (
                    actual_high_start_time == 0
                ) begin

                    high_timing_error_count =
                        high_timing_error_count + 1;

                    $error(
                        "[FAIL] NO_ACTUAL_HIGH_START_FOR_RECOVERY_PULSE_%0d",
                        dut.recovery_pulse_count
                    );

                end
                else if (
                    ($time - actual_high_start_time) <
                    HALF_PERIOD_NS
                ) begin

                    high_timing_error_count =
                        high_timing_error_count + 1;

                    $error(
                        "[FAIL] RECOVERY_HIGH_TOO_SHORT pulse=%0d duration=%0t expected>=%0t",
                        dut.recovery_pulse_count,
                        ($time - actual_high_start_time),
                        HALF_PERIOD_NS
                    );

                end
                else begin

                    $display(
                        "[PASS] RECOVERY_HIGH_TIMING pulse=%0d duration=%0t",
                        dut.recovery_pulse_count,
                        ($time - actual_high_start_time)
                    );

                end

            end

        end

    end


    /*
     * ================================================================
     * Capture first SDA-release pulse before manager later clears its
     * internal measurement register on return to RM_IDLE.
     * ================================================================
     */
    always @(dut.sda_release_pulse) begin

        if (
            rst_n &&
            timing_monitor_enable &&
            (dut.sda_release_pulse != 0) &&
            (observed_sda_release_pulse == 0)
        ) begin

            observed_sda_release_pulse =
                dut.sda_release_pulse;

            $display(
                "[INFO] RECORDED SDA RELEASE PULSE = %0d",
                observed_sda_release_pulse
            );

        end

    end


    /*
     * ================================================================
     * Event counters
     * ================================================================
     */
    always @(posedge fault_abort) begin

        if (rst_n) begin
            fault_abort_count = fault_abort_count + 1;
        end

    end


    always @(posedge fault_done_pulse) begin

        if (rst_n) begin
            fault_done_count = fault_done_count + 1;
        end

    end


    /*
     * ================================================================
     * Successful release cases: 1 / 3 / 5 / 9
     * ================================================================
     */
    task automatic test_success_release_pulse(
        input integer requested_release_pulse
    );
        begin

            $display("");
            $display(
                "===== TEST F1 SDA RELEASE ON PULSE %0d =====",
                requested_release_pulse
            );

            reset_dut();

            start_f1_fault(
                requested_release_pulse
            );

            wait_for_f1_success();

            timing_monitor_enable = 1'b0;

            check(
                $sformatf(
                    "F1_RELEASE_%0d_EXACTLY_NINE_LOW_PULSES",
                    requested_release_pulse
                ),
                recovery_low_pulse_count == 9
            );

            check(
                $sformatf(
                    "F1_RELEASE_%0d_NINE_COMPLETED_CLOCKS",
                    requested_release_pulse
                ),
                max_completed_pulse_count == 9
            );

            check(
                $sformatf(
                    "F1_RELEASE_%0d_RECORDED_CORRECTLY",
                    requested_release_pulse
                ),
                observed_sda_release_pulse ==
                requested_release_pulse
            );

            check(
                "F1_ALL_LOW_INTERVALS_VALID",
                low_timing_error_count == 0
            );

            check(
                "F1_ALL_HIGH_INTERVALS_VALID",
                high_timing_error_count == 0
            );

            check(
                "F1_SINGLE_CORE_ABORT",
                fault_abort_count == 1
            );

            check(
                "F1_AUTONOMOUS_RECOVERY_NO_FALSE_DONE",
                fault_done_count == 0
            );

            check(
                "F1_SUCCESS_STATUS_REMAINS_ACTIVE",
                fault_active == 1'b1
            );

            check(
                "F1_SUCCESS_CODE_REMAINS_SDA_STUCK",
                fault_code == 2'b01
            );

            check(
                "F1_SUCCESS_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "F1_SUCCESS_COMMAND_BLOCK_REMOVED",
                block_cmd_ready == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * Recovery-clock stretch test
     * ================================================================
     *
     * Hold physical SCL LOW after the manager releases it during the
     * first recovery clock. Completed pulse count must not advance.
     * ================================================================
     */
    task automatic test_recovery_scl_stretch;

        integer before_count;

        begin

            $display("");
            $display(
                "===== TEST F1 RECOVERY SCL STRETCH ====="
            );

            reset_dut();

            start_f1_fault(3);

            /*
             * First recovery LOW interval begins.
             */
            @(posedge recovery_scl_drive_low);

            /*
             * Assert external SCL hold while the manager itself is
             * already driving LOW.
             */
            @(negedge clk);
            ext_scl_hold_low = 1'b1;

            /*
             * Wait for manager to release its SCL drive.
             * Physical SCL must remain LOW because the external hold
             * is still active.
             */
            @(negedge recovery_scl_drive_low);
            #1;

            before_count = dut.recovery_pulse_count;

            check(
                "RECOVERY_STRETCH_MANAGER_RELEASED_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "RECOVERY_STRETCH_PHYSICAL_SCL_REMAINS_LOW",
                scl_in == 1'b0
            );

            /*
             * Wait well beyond the normal HIGH half-period but far
             * below the deliberately large F2 threshold.
             */
            wait_cycles(
                HALF_PERIOD_CYCLES + 4
            );

            check(
                "RECOVERY_STRETCH_NO_COMPLETED_CLOCK_PROGRESS",
                dut.recovery_pulse_count == before_count
            );

            check(
                "RECOVERY_STRETCH_NO_FORCED_SCL_HIGH",
                scl_in == 1'b0
            );

            /*
             * External device finally releases SCL.
             */
            @(negedge clk);
            ext_scl_hold_low = 1'b0;

            wait_for_f1_success();

            timing_monitor_enable = 1'b0;

            check(
                "RECOVERY_STRETCH_STILL_EXACTLY_NINE_PULSES",
                recovery_low_pulse_count == 9
            );

            check(
                "RECOVERY_STRETCH_COMPLETES_NINE_CLOCKS",
                max_completed_pulse_count == 9
            );

            check(
                "RECOVERY_STRETCH_RELEASE_PULSE_RECORDED",
                observed_sda_release_pulse == 3
            );

            check(
                "RECOVERY_STRETCH_LOW_TIMING_VALID",
                low_timing_error_count == 0
            );

            check(
                "RECOVERY_STRETCH_HIGH_TIMING_VALID",
                high_timing_error_count == 0
            );

            check(
                "RECOVERY_STRETCH_NO_FALSE_DONE",
                fault_done_count == 0
            );

        end

    endtask


    /*
     * ================================================================
     * tBUF disturbance test
     * ================================================================
     */
    task automatic test_tbuf_restart;

        time disturbance_release_time;
        time success_time;

        begin

            $display("");
            $display(
                "===== TEST F1 tBUF RESTART ====="
            );

            reset_dut();

            start_f1_fault(1);

            /*
             * Wait until all nine recovery clocks have completed.
             */
            wait (
                max_completed_pulse_count == 9
            );

            /*
             * Give the manager a few cycles of initially free bus,
             * but not enough to satisfy the 47-cycle scaled tBUF.
             */
            wait_cycles(8);

            @(negedge clk);
            ext_sda_hold_low = 1'b1;

            wait_cycles(3);

            check(
                "TBUF_DISTURBANCE_RECOVERY_STILL_ACTIVE",
                recovery_active == 1'b1
            );

            @(negedge clk);
            ext_sda_hold_low = 1'b0;

            disturbance_release_time = $time;

            wait_for_f1_success();

            success_time = $time;

            timing_monitor_enable = 1'b0;

            check(
                "TBUF_REQUIRES_FRESH_CONTINUOUS_INTERVAL",
                (success_time - disturbance_release_time) >=
                (T_BUF_CYCLES * CLK_PERIOD_NS)
            );

            check(
                "TBUF_RESTART_NO_FALSE_DONE",
                fault_done_count == 0
            );

            check(
                "TBUF_RESTART_FINISHES_WITH_SUCCESS",
                recovery_failed == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * Successful-status clear-on-next-command policy
     * ================================================================
     */
    task automatic test_success_status_clear;
        begin

            $display("");
            $display(
                "===== TEST F1 SUCCESS STATUS CLEAR ====="
            );

            reset_dut();

            start_f1_fault(5);

            wait_for_f1_success();

            timing_monitor_enable = 1'b0;

            check(
                "PRE_COMMAND_FAULT_STATUS_LATCHED",
                fault_active == 1'b1
            );

            check(
                "PRE_COMMAND_FAULT_CODE_LATCHED",
                fault_code == 2'b01
            );

            /*
             * Model the next command actually being accepted.
             */
            @(negedge clk);
            cmd_accept = 1'b1;

            @(posedge clk);
            #1;

            @(negedge clk);
            cmd_accept = 1'b0;

            @(posedge clk);
            #1;

            check(
                "NEXT_ACCEPTED_COMMAND_CLEARS_FAULT_ACTIVE",
                fault_active == 1'b0
            );

            check(
                "NEXT_ACCEPTED_COMMAND_CLEARS_FAULT_CODE",
                fault_code == 2'b00
            );

        end

    endtask


    /*
     * ================================================================
     * Never-release failure case
     * ================================================================
     */
    task automatic test_f1_failure;
        begin

            $display("");
            $display(
                "===== TEST F1 NEVER RELEASES ====="
            );

            reset_dut();

            /*
             * release_on_pulse = 0 means external SDA remains stuck
             * LOW through all nine recovery clocks.
             */
            start_f1_fault(0);

            wait_for_f1_failure();

            timing_monitor_enable = 1'b0;

            check(
                "F1_FAILURE_EXACTLY_NINE_LOW_PULSES",
                recovery_low_pulse_count == 9
            );

            check(
                "F1_FAILURE_NINE_COMPLETED_CLOCKS",
                max_completed_pulse_count == 9
            );

            check(
                "F1_FAILURE_NO_RELEASE_PULSE_RECORDED",
                observed_sda_release_pulse == 0
            );

            check(
                "F1_FAILURE_STATUS_ACTIVE",
                fault_active == 1'b1
            );

            check(
                "F1_FAILURE_CODE_SDA_STUCK",
                fault_code == 2'b01
            );

            check(
                "F1_FAILURE_RECOVERY_FAILED_LATCHED",
                recovery_failed == 1'b1
            );

            check(
                "F1_FAILURE_COMMANDS_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "F1_FAILURE_OWNS_BUS",
                recovery_owns_bus == 1'b1
            );

            check(
                "F1_FAILURE_RELEASES_SDA_OUTPUT",
                recovery_sda_drive_low == 1'b0
            );

            check(
                "F1_FAILURE_RELEASES_SCL_OUTPUT",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "F1_FAILURE_NO_FALSE_DONE",
                fault_done_count == 0
            );

            check(
                "F1_FAILURE_SINGLE_CORE_ABORT",
                fault_abort_count == 1
            );


            /*
             * Neither bus release nor a new command may escape the
             * reset-only F1_FAILED terminal state.
             */
            @(negedge clk);

            ext_sda_hold_low = 1'b0;
            cmd_accept = 1'b1;

            wait_cycles(10);

            cmd_accept = 1'b0;

            check(
                "F1_FAILED_REMAINS_LATCHED_WITHOUT_RESET",
                recovery_failed == 1'b1
            );

            check(
                "F1_FAILED_STILL_BLOCKS_COMMANDS",
                block_cmd_ready == 1'b1
            );

            check(
                "F1_FAILED_FAULT_STATUS_STILL_LATCHED",
                fault_active &&
                (fault_code == 2'b01)
            );


            /*
             * Reset is the only supported clear mechanism.
             */
            reset_dut();

            check(
                "RESET_CLEARS_FAILED_RECOVERY",
                recovery_failed == 1'b0
            );

            check(
                "RESET_CLEARS_FAILED_FAULT_STATUS",
                !fault_active &&
                (fault_code == 2'b00)
            );

        end

    endtask


    /*
     * ================================================================
     * Watchdog
     * ================================================================
     */
    initial begin

        #20_000_000;

        $fatal(
            1,
            "S6.3B F1 recovery unit-test watchdog expired"
        );

    end


    /*
     * ================================================================
     * Main sequence
     * ================================================================
     */
    initial begin

        error_count = 0;

        clear_metrics();

        rst_n = 1'b0;

        cmd_accept = 1'b0;

        core_expect_bus_free = 1'b0;
        core_waiting_for_scl_high = 1'b0;
        core_transaction_active = 1'b0;
        core_scl_drive_low = 1'b0;

        ext_sda_hold_low = 1'b0;
        ext_scl_hold_low = 1'b0;

        release_on_pulse = 0;
        timing_monitor_enable = 1'b0;


        test_success_release_pulse(1);
        test_success_release_pulse(3);
        test_success_release_pulse(5);
        test_success_release_pulse(9);

        test_recovery_scl_stretch();

        test_tbuf_restart();

        test_success_status_clear();

        test_f1_failure();


        $display("");
        $display(
            "============================================"
        );

        if (error_count == 0) begin

            $display(
                "S6.3B F1 RECOVERY UNIT TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

        end
        else begin

            $display(
                "S6.3B F1 RECOVERY UNIT TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $fatal(
                1,
                "S6.3B F1 recovery verification failed"
            );

        end

        $display(
            "============================================"
        );

        $finish;

    end

endmodule