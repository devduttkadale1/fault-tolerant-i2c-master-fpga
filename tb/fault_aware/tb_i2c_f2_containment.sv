`timescale 1ns/1ps

module tb_i2c_f2_containment;

    /*
     * ================================================================
     * Accelerated unit-test configuration
     * ================================================================
     */
    localparam integer SYS_CLK_HZ = 10_000_000;
    localparam integer I2C_CLK_HZ = 1_000_000;

    /*
     * F1 is deliberately kept out of this F2-focused unit test.
     */
    localparam integer F1_LIMIT = 1_000;

    /*
     * Small F2 threshold so exact boundary behavior is easy to prove.
     */
    localparam integer F2_LIMIT = 5;

    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;

    localparam time CLK_PERIOD_NS =
        1_000_000_000 / SYS_CLK_HZ;


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

    integer fault_abort_count;
    integer fault_done_count;

    integer recovery_scl_low_violation_count;
    integer recovery_sda_low_violation_count;

    integer busy_hold_seen;

    logic f2_monitor_enable;

    time final_bus_free_time;
    time completion_time;


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
     * When the recovery manager owns the bus, the common-core SCL
     * intent is excluded exactly as the future wrapper mux will do.
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
     * Metrics
     * ================================================================
     */
    task automatic clear_metrics;
        begin

            fault_abort_count = 0;
            fault_done_count = 0;

            recovery_scl_low_violation_count = 0;
            recovery_sda_low_violation_count = 0;

            busy_hold_seen = 0;

            final_bus_free_time = 0;
            completion_time = 0;

        end

    endtask


    /*
     * ================================================================
     * Reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            f2_monitor_enable = 1'b0;

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

            clear_metrics();

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

            check(
                "RESET_BUSY_HOLD_CLEAR",
                fault_busy_hold == 1'b0
            );

            check(
                "RESET_DONE_CLEAR",
                fault_done_pulse == 1'b0
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


    /*
     * F2 containment is release-only.
     *
     * Any rising edge of either recovery drive-low signal during an
     * F2 scenario is a design violation.
     */
    always @(posedge recovery_scl_drive_low) begin

        if (
            rst_n &&
            f2_monitor_enable
        ) begin

            recovery_scl_low_violation_count =
                recovery_scl_low_violation_count + 1;

            $error(
                "[FAIL] F2_ILLEGAL_RECOVERY_SCL_LOW_DRIVE"
            );

            error_count = error_count + 1;

        end

    end


    always @(posedge recovery_sda_drive_low) begin

        if (
            rst_n &&
            f2_monitor_enable
        ) begin

            recovery_sda_low_violation_count =
                recovery_sda_low_violation_count + 1;

            $error(
                "[FAIL] F2_ILLEGAL_RECOVERY_SDA_LOW_DRIVE"
            );

            error_count = error_count + 1;

        end

    end


    always @(posedge clk) begin

        if (
            rst_n &&
            f2_monitor_enable &&
            fault_busy_hold
        ) begin

            busy_hold_seen = 1;

        end

    end


    /*
     * ================================================================
     * Test 1:
     * intentional controller SCL LOW must never classify as F2
     * ================================================================
     */
    task automatic test_intentional_scl_low_filter;
        begin

            $display("");
            $display(
                "===== TEST F2 INTENTIONAL SCL LOW FILTER ====="
            );

            reset_dut();

            f2_monitor_enable = 1'b1;

            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;

            /*
             * Controller itself intentionally owns LOW.
             */
            core_scl_drive_low = 1'b1;

            ext_scl_hold_low = 1'b0;

            wait_cycles(
                F2_LIMIT + 4
            );

            check(
                "F2_FILTER_PHYSICAL_SCL_IS_LOW",
                scl_in == 1'b0
            );

            check(
                "F2_NOT_DETECTED_DURING_CONTROLLER_LOW",
                fault_active == 1'b0
            );

            check(
                "F2_FILTER_NO_ABORT",
                fault_abort_count == 0
            );

            check(
                "F2_FILTER_NO_DONE",
                fault_done_count == 0
            );

            @(negedge clk);

            core_waiting_for_scl_high = 1'b0;
            core_scl_drive_low = 1'b0;

            f2_monitor_enable = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Test 2:
     * legal short stretch = exactly LIMIT-1 qualifying samples
     * ================================================================
     */
    task automatic test_short_stretch;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 LEGAL SHORT STRETCH ====="
            );

            reset_dut();

            f2_monitor_enable = 1'b1;

            @(negedge clk);

            core_waiting_for_scl_high = 1'b1;
            core_scl_drive_low = 1'b0;
            core_transaction_active = 1'b1;

            ext_scl_hold_low = 1'b1;


            for (
                i = 1;
                i <= (F2_LIMIT - 1);
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                check(
                    $sformatf(
                        "F2_SHORT_STRETCH_SAMPLE_%0d_NO_DETECT",
                        i
                    ),
                    dut.f2_detect_pulse == 1'b0
                );

            end


            @(negedge clk);

            ext_scl_hold_low = 1'b0;

            wait_cycles(3);

            check(
                "LEGAL_SHORT_STRETCH_NO_F2",
                fault_active == 1'b0
            );

            check(
                "LEGAL_SHORT_STRETCH_NO_ABORT",
                fault_abort_count == 0
            );

            check(
                "LEGAL_SHORT_STRETCH_NO_DONE",
                fault_done_count == 0
            );

            @(negedge clk);

            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;

            f2_monitor_enable = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Exact F2 threshold helper
     * ================================================================
     *
     * This deliberately proves detector boundary behavior again at
     * the manager integration boundary.
     */
    task automatic trigger_exact_f2(
        input logic active_transaction
    );

        integer i;

        begin

            clear_metrics();

            f2_monitor_enable = 1'b1;

            @(negedge clk);

            core_expect_bus_free = 1'b0;
            core_waiting_for_scl_high = 1'b1;
            core_scl_drive_low = 1'b0;

            core_transaction_active =
                active_transaction;

            ext_sda_hold_low = 1'b0;
            ext_scl_hold_low = 1'b1;


            /*
             * Samples 1 through LIMIT-1 must not classify.
             */
            for (
                i = 1;
                i <= (F2_LIMIT - 1);
                i = i + 1
            ) begin

                @(posedge clk);
                #1;

                check(
                    $sformatf(
                        "F2_BELOW_LIMIT_SAMPLE_%0d",
                        i
                    ),
                    dut.f2_detect_pulse == 1'b0
                );

                check(
                    $sformatf(
                        "F2_BELOW_LIMIT_SAMPLE_%0d_NO_MANAGER_FAULT",
                        i
                    ),
                    fault_active == 1'b0
                );

            end


            /*
             * Exact qualifying sample N.
             */
            @(posedge clk);
            #1;

            check(
                "F2_DETECT_EXACTLY_AT_LIMIT",
                dut.f2_detect_pulse == 1'b1
            );


            /*
             * The detector pulse is consumed by the sequential manager
             * on the following system-clock edge.
             */
            @(posedge clk);
            #1;

            check(
                "F2_MANAGER_LATCHES_FAULT_ACTIVE",
                fault_active == 1'b1
            );

            check(
                "F2_MANAGER_LATCHES_SCL_STALL_CODE",
                fault_code == 2'b10
            );

            check(
                "F2_MANAGER_BLOCKS_NEW_COMMANDS",
                block_cmd_ready == 1'b1
            );

            check(
                "F2_MANAGER_TAKES_BUS_OWNERSHIP",
                recovery_owns_bus == 1'b1
            );

            check(
                "F2_MANAGER_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "F2_MANAGER_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );

            check(
                "F2_BUSY_HOLD_MATCHES_CAPTURED_TRANSACTION",
                fault_busy_hold ==
                active_transaction
            );

            check(
                "F2_SINGLE_ABORT_LAUNCHED",
                fault_abort_count == 1
            );


            /*
             * Model the common core responding to the abort.
             *
             * Keep external SCL held LOW so containment must continue.
             */
            @(negedge clk);

            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;


            /*
             * Verify the abort signal itself was a pulse rather than
             * being held throughout containment.
             */
            @(posedge clk);
            #1;

            check(
                "F2_ABORT_IS_ONE_CYCLE",
                fault_abort == 1'b0
            );

            check(
                "F2_ABORT_COUNT_REMAINS_ONE",
                fault_abort_count == 1
            );

        end

    endtask


    /*
     * ================================================================
     * Wait for a no-command F2 return to service.
     * ================================================================
     */
    task automatic wait_for_f2_return_without_done;

        integer guard;

        begin

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
                        "Timed out waiting for F2 containment completion"
                    );

                end

            end

        end

    endtask


    /*
     * ================================================================
     * Test 3:
     * active transaction + extended hold + bus-free wait + tBUF restart
     * + exactly one fault-termination done pulse
     * ================================================================
     */
    task automatic test_active_transaction_f2;

        integer guard;

        begin

            $display("");
            $display(
                "===== TEST F2 ACTIVE TRANSACTION CONTAINMENT ====="
            );

            reset_dut();

            trigger_exact_f2(
                1'b1
            );


            /*
             * Continue holding SCL LOW well beyond detection.
             */
            wait_cycles(
                F2_LIMIT + 12
            );

            check(
                "F2_EXTENDED_HOLD_REMAINS_CONTAINED",
                recovery_owns_bus == 1'b1
            );

            check(
                "F2_EXTENDED_HOLD_RECOVERY_ACTIVE",
                recovery_active == 1'b1
            );

            check(
                "F2_EXTENDED_HOLD_COMMANDS_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "F2_EXTENDED_HOLD_BUSY_PRESERVED",
                fault_busy_hold == 1'b1
            );

            check(
                "F2_EXTENDED_HOLD_NO_DONE",
                fault_done_count == 0
            );

            check(
                "F2_EXTENDED_HOLD_SCL_REMAINS_EXTERNAL_LOW",
                scl_in == 1'b0
            );

            check(
                "F2_NEVER_FORCES_SCL_LOW",
                recovery_scl_low_violation_count == 0
            );

            check(
                "F2_NEVER_FORCES_SDA_LOW",
                recovery_sda_low_violation_count == 0
            );


            /*
             * SCL holder releases, but SDA is deliberately still LOW.
             *
             * The controller must transition only as far as the
             * complete-bus-free wait.
             */
            @(negedge clk);

            ext_sda_hold_low = 1'b1;
            ext_scl_hold_low = 1'b0;

            wait_cycles(6);

            check(
                "F2_SCL_RELEASED_PHYSICAL_HIGH",
                scl_in == 1'b1
            );

            check(
                "F2_SDA_LOW_PREVENTS_BUS_FREE",
                sda_in == 1'b0
            );

            check(
                "F2_SDA_LOW_STILL_CONTAINED",
                recovery_owns_bus == 1'b1
            );

            check(
                "F2_SDA_LOW_BUSY_STILL_HELD",
                fault_busy_hold == 1'b1
            );

            check(
                "F2_SDA_LOW_NO_DONE",
                fault_done_count == 0
            );


            /*
             * Release SDA and allow only a partial tBUF interval.
             */
            @(negedge clk);
            ext_sda_hold_low = 1'b0;

            wait_cycles(8);

            check(
                "F2_PARTIAL_TBUF_STILL_CONTAINED",
                recovery_owns_bus == 1'b1
            );

            check(
                "F2_PARTIAL_TBUF_BUSY_STILL_HELD",
                fault_busy_hold == 1'b1
            );

            check(
                "F2_PARTIAL_TBUF_NO_DONE",
                fault_done_count == 0
            );


            /*
             * Disturb the bus before tBUF can finish.
             */
            @(negedge clk);
            ext_sda_hold_low = 1'b1;

            wait_cycles(4);

            check(
                "F2_TBUF_DISTURBANCE_REMAINS_CONTAINED",
                recovery_active == 1'b1
            );

            check(
                "F2_TBUF_DISTURBANCE_BUSY_PRESERVED",
                fault_busy_hold == 1'b1
            );

            check(
                "F2_TBUF_DISTURBANCE_NO_DONE",
                fault_done_count == 0
            );


            /*
             * Final release. From here a completely fresh continuous
             * tBUF interval is mandatory.
             */
            @(negedge clk);

            ext_sda_hold_low = 1'b0;

            final_bus_free_time = $time;


            /*
             * Wait for the frozen one-cycle fault completion.
             */
            guard = 0;

            while (!fault_done_pulse) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 5000) begin

                    $fatal(
                        1,
                        "Timed out waiting for active-transaction F2 done"
                    );

                end

            end

            completion_time = $time;


            check(
                "F2_TBUF_REQUIRES_FRESH_CONTINUOUS_INTERVAL",
                (
                    completion_time -
                    final_bus_free_time
                ) >=
                (
                    T_BUF_CYCLES *
                    CLK_PERIOD_NS
                )
            );

            check(
                "F2_ACTIVE_TRANSACTION_DONE_ASSERTED",
                fault_done_pulse == 1'b1
            );

            check(
                "F2_ACTIVE_TRANSACTION_EXACTLY_ONE_DONE_SO_FAR",
                fault_done_count == 1
            );

            check(
                "F2_SUCCESS_BUSY_RELEASED",
                fault_busy_hold == 1'b0
            );

            check(
                "F2_SUCCESS_RECOVERY_INACTIVE",
                recovery_active == 1'b0
            );

            check(
                "F2_SUCCESS_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "F2_SUCCESS_BUS_OWNERSHIP_RETURNED",
                recovery_owns_bus == 1'b0
            );

            check(
                "F2_SUCCESS_COMMAND_BLOCK_REMOVED",
                block_cmd_ready == 1'b0
            );

            check(
                "F2_SUCCESS_FAULT_STATUS_LATCHED",
                fault_active == 1'b1
            );

            check(
                "F2_SUCCESS_FAULT_CODE_LATCHED",
                fault_code == 2'b10
            );

            check(
                "F2_SUCCESS_ABORT_COUNT_ONE",
                fault_abort_count == 1
            );

            check(
                "F2_ACTIVE_CASE_BUSY_HOLD_WAS_OBSERVED",
                busy_hold_seen == 1
            );

            check(
                "F2_SUCCESS_NEVER_FORCED_SCL",
                recovery_scl_low_violation_count == 0
            );

            check(
                "F2_SUCCESS_NEVER_FORCED_SDA",
                recovery_sda_low_violation_count == 0
            );


            /*
             * The completion event must be exactly one system-clock
             * cycle.
             */
            @(posedge clk);
            #1;

            check(
                "F2_DONE_DEASSERTS_AFTER_ONE_CYCLE",
                fault_done_pulse == 1'b0
            );

            wait_cycles(4);

            check(
                "F2_NO_REPEATED_DONE",
                fault_done_count == 1
            );

            check(
                "F2_STATUS_PERSISTS_AFTER_SUCCESS",
                fault_active &&
                (fault_code == 2'b10)
            );


            /*
             * Next successfully accepted command clears the historical
             * successful-fault indication.
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
                "F2_NEXT_COMMAND_CLEARS_FAULT_ACTIVE",
                fault_active == 1'b0
            );

            check(
                "F2_NEXT_COMMAND_CLEARS_FAULT_CODE",
                fault_code == 2'b00
            );

            check(
                "F2_STATUS_CLEAR_DOES_NOT_CREATE_DONE",
                fault_done_count == 1
            );

            f2_monitor_enable = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Test 4:
     * F2 without an active command must not invent busy/done semantics.
     * ================================================================
     */
    task automatic test_no_active_transaction_f2;
        begin

            $display("");
            $display(
                "===== TEST F2 WITHOUT ACTIVE TRANSACTION ====="
            );

            reset_dut();

            trigger_exact_f2(
                1'b0
            );

            check(
                "F2_NO_ACTIVE_TRANSACTION_NO_BUSY_HOLD",
                fault_busy_hold == 1'b0
            );


            /*
             * Extended containment while externally held LOW.
             */
            wait_cycles(
                F2_LIMIT + 8
            );

            check(
                "F2_NO_ACTIVE_EXTENDED_HOLD_CONTAINED",
                recovery_owns_bus == 1'b1
            );

            check(
                "F2_NO_ACTIVE_EXTENDED_HOLD_NO_BUSY",
                fault_busy_hold == 1'b0
            );

            check(
                "F2_NO_ACTIVE_EXTENDED_HOLD_NO_DONE",
                fault_done_count == 0
            );


            /*
             * Release SCL. SDA is already free.
             */
            @(negedge clk);
            ext_scl_hold_low = 1'b0;

            wait_for_f2_return_without_done();

            check(
                "F2_NO_ACTIVE_RETURNS_TO_SERVICE",
                !recovery_owns_bus &&
                !block_cmd_ready
            );

            check(
                "F2_NO_ACTIVE_NEVER_ASSERTED_BUSY_HOLD",
                busy_hold_seen == 0
            );

            check(
                "F2_NO_ACTIVE_GENERATES_NO_DONE",
                fault_done_count == 0
            );

            check(
                "F2_NO_ACTIVE_ABORT_COUNT_ONE",
                fault_abort_count == 1
            );

            check(
                "F2_NO_ACTIVE_FAULT_STATUS_LATCHED",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "F2_NO_ACTIVE_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "F2_NO_ACTIVE_NEVER_FORCED_SCL",
                recovery_scl_low_violation_count == 0
            );

            check(
                "F2_NO_ACTIVE_NEVER_FORCED_SDA",
                recovery_sda_low_violation_count == 0
            );

            /*
             * Remain in service for several cycles to prove no delayed
             * synthetic completion appears.
             */
            wait_cycles(8);

            check(
                "F2_NO_ACTIVE_NO_DELAYED_DONE",
                fault_done_count == 0
            );

            f2_monitor_enable = 1'b0;

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
            "S6.3D F2 containment unit-test watchdog expired"
        );

    end


    /*
     * ================================================================
     * Main
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

        f2_monitor_enable = 1'b0;


        test_intentional_scl_low_filter();

        test_short_stretch();

        test_active_transaction_f2();

        test_no_active_transaction_f2();


        $display("");
        $display(
            "============================================"
        );

        if (error_count == 0) begin

            $display(
                "S6.3D F2 CONTAINMENT UNIT TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

        end
        else begin

            $display(
                "S6.3D F2 CONTAINMENT UNIT TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $fatal(
                1,
                "S6.3D F2 containment verification failed"
            );

        end

        $display(
            "============================================"
        );

        $finish;

    end

endmodule