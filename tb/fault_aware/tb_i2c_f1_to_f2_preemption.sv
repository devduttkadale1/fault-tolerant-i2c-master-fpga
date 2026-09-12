`timescale 1ns/1ps

module tb_i2c_f1_to_f2_preemption;

    /*
     * ================================================================
     * Accelerated unit-test configuration
     * ================================================================
     *
     * Production defaults remain:
     *
     *     SYS_CLK_HZ = 100 MHz
     *     I2C_CLK_HZ = 100 kHz
     *
     * These smaller values are used only to accelerate this focused
     * manager-level unit test.
     */
    localparam integer SYS_CLK_HZ = 10_000_000;
    localparam integer I2C_CLK_HZ = 1_000_000;

    localparam integer F1_LIMIT = 3;
    localparam integer F2_LIMIT = 5;

    localparam integer HALF_PERIOD_CYCLES =
        SYS_CLK_HZ / (2 * I2C_CLK_HZ);

    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;

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
     * Verification bookkeeping
     * ================================================================
     */
    integer error_count;

    integer fault_abort_count;
    integer fault_done_count;

    integer recovery_scl_low_pulse_count;
    integer post_f2_scl_low_violation_count;
    integer recovery_sda_low_violation_count;

    integer f2_reclassification_seen;

    integer i;
    integer guard;

    time final_bus_free_time;
    time containment_complete_time;

    logic scenario_enable;


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
     * Open-drain resolved bus
     * ================================================================
     *
     * The common core is not instantiated in this unit test.
     *
     * recovery_owns_bus models the ownership mux that will later be
     * present in the complete fault-aware wrapper.
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

                error_count =
                    error_count + 1;

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

        integer cycle_index;

        begin

            for (
                cycle_index = 0;
                cycle_index < count;
                cycle_index = cycle_index + 1
            ) begin

                @(posedge clk);

            end

            #1;

        end

    endtask


    /*
     * ================================================================
     * Metrics reset
     * ================================================================
     */
    task automatic clear_metrics;
        begin

            fault_abort_count = 0;
            fault_done_count = 0;

            recovery_scl_low_pulse_count = 0;
            post_f2_scl_low_violation_count = 0;
            recovery_sda_low_violation_count = 0;

            f2_reclassification_seen = 0;

            final_bus_free_time = 0;
            containment_complete_time = 0;

        end

    endtask


    /*
     * ================================================================
     * DUT reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            scenario_enable = 1'b0;

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

        if (
            rst_n &&
            scenario_enable
        ) begin

            fault_abort_count =
                fault_abort_count + 1;

        end

    end


    always @(posedge fault_done_pulse) begin

        if (
            rst_n &&
            scenario_enable
        ) begin

            fault_done_count =
                fault_done_count + 1;

        end

    end


    /*
     * Count legitimate F1 recovery LOW pulses.
     *
     * Once F2 reclassification has happened, no additional recovery
     * clock LOW pulse is allowed.
     */
    always @(posedge recovery_scl_drive_low) begin

        if (
            rst_n &&
            scenario_enable
        ) begin

            recovery_scl_low_pulse_count =
                recovery_scl_low_pulse_count + 1;

            if (f2_reclassification_seen != 0) begin

                post_f2_scl_low_violation_count =
                    post_f2_scl_low_violation_count + 1;

                $error(
                    "[FAIL] F1_CLOCK_GENERATION_CONTINUED_AFTER_F2"
                );

                error_count =
                    error_count + 1;

            end

        end

    end


    /*
     * Neither F1 bus-clear recovery nor F2 containment should actively
     * pull SDA LOW.
     */
    always @(posedge recovery_sda_drive_low) begin

        if (
            rst_n &&
            scenario_enable
        ) begin

            recovery_sda_low_violation_count =
                recovery_sda_low_violation_count + 1;

            $error(
                "[FAIL] COMPOUND_RECOVERY_ILLEGAL_SDA_LOW_DRIVE"
            );

            error_count =
                error_count + 1;

        end

    end


    /*
     * Once FAULT_SCL_STALL becomes visible, remember that the
     * sequential reclassification has happened.
     */
    always @(posedge clk) begin

        if (
            rst_n &&
            scenario_enable
        ) begin

            #1;

            if (
                fault_active &&
                (fault_code == 2'b10)
            ) begin

                f2_reclassification_seen = 1;

            end

        end

    end


    /*
     * ================================================================
     * Main compound-fault test
     * ================================================================
     */
    task automatic test_f1_to_f2_preemption;
        begin

            $display("");
            $display(
                "===== TEST F1 TO F2 PREEMPTION ====="
            );

            reset_dut();

            scenario_enable = 1'b1;


            /*
             * ========================================================
             * STEP 1 — create F1
             * ========================================================
             *
             * The normal controller expects a free bus, SCL is HIGH,
             * but an external device holds SDA LOW.
             */
            @(negedge clk);

            core_expect_bus_free = 1'b1;
            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b1;
            ext_scl_hold_low = 1'b0;


            /*
             * Wait for F1 classification and the original one-cycle
             * common-core abort.
             */
            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01) &&
                    recovery_owns_bus &&
                    (fault_abort_count == 1)
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 200) begin

                    $fatal(
                        1,
                        "Timed out waiting for F1 detection"
                    );

                end

            end


            check(
                "F12_F1_CLASSIFIED_FIRST",
                fault_active &&
                (fault_code == 2'b01)
            );

            check(
                "F12_F1_SINGLE_INITIAL_ABORT",
                fault_abort_count == 1
            );

            check(
                "F12_AUTONOMOUS_F1_HAS_NO_BUSY_HOLD",
                fault_busy_hold == 1'b0
            );

            check(
                "F12_AUTONOMOUS_F1_HAS_NO_DONE",
                fault_done_count == 0
            );


            /*
             * ========================================================
             * STEP 2 — allow the first recovery LOW pulse to start
             * ========================================================
             */
            guard = 0;

            while (
                recovery_scl_low_pulse_count < 1
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 200) begin

                    $fatal(
                        1,
                        "Timed out waiting for first F1 recovery pulse"
                    );

                end

            end


            check(
                "F12_FIRST_F1_LOW_PULSE_STARTED",
                recovery_scl_low_pulse_count == 1
            );


            /*
             * Hold external SCL LOW while the manager is still inside
             * the legitimate first F1 LOW interval.
             *
             * When the manager later releases SCL, physical SCL will
             * therefore remain LOW.
             */
            @(negedge clk);

            ext_scl_hold_low = 1'b1;


            /*
             * ========================================================
             * STEP 3 — wait until F1 has released SCL and enabled the
             * F2 detector context
             * ========================================================
             */
            guard = 0;

            while (
                !(
                    dut.detector_f2_monitor_enable &&
                    dut.detector_waiting_for_scl_high &&
                    !dut.detector_scl_drive_low &&
                    !scl_in
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 300) begin

                    $fatal(
                        1,
                        "Timed out waiting for F1_WAIT_SCL_HIGH"
                    );

                end

            end


            check(
                "F12_F2_MONITOR_ENABLED_DURING_F1_WAIT",
                dut.detector_f2_monitor_enable == 1'b1
            );

            check(
                "F12_F1_MONITOR_DISABLED_DURING_F1_WAIT",
                dut.detector_f1_monitor_enable == 1'b0
            );

            check(
                "F12_RECOVERY_MANAGER_RELEASED_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "F12_PHYSICAL_SCL_STILL_EXTERNALLY_LOW",
                scl_in == 1'b0
            );

            check(
                "F12_FAULT_STILL_SDA_STUCK_BEFORE_F2_LIMIT",
                fault_active &&
                (fault_code == 2'b01)
            );


            /*
             * ========================================================
             * STEP 4 — prove LIMIT-1 samples do not preempt F1
             * ========================================================
             *
             * The context became active after the preceding state
             * transition. The following positive clock edges are the
             * qualifying F2 samples.
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
                        "F12_F2_SAMPLE_%0d_BELOW_LIMIT",
                        i
                    ),
                    dut.f2_detect_pulse == 1'b0
                );

                check(
                    $sformatf(
                        "F12_SAMPLE_%0d_STILL_CLASSIFIED_F1",
                        i
                    ),
                    fault_active &&
                    (fault_code == 2'b01)
                );

                check(
                    $sformatf(
                        "F12_SAMPLE_%0d_NO_EXTRA_F1_LOW_PULSE",
                        i
                    ),
                    recovery_scl_low_pulse_count == 1
                );

            end


            /*
             * Exact F2 threshold.
             *
             * At this edge the detector pulse appears. The sequential
             * manager consumes that pulse on the following clock.
             */
            @(posedge clk);
            #1;

            check(
                "F12_F2_DETECT_EXACTLY_AT_LIMIT",
                dut.f2_detect_pulse == 1'b1
            );

            check(
                "F12_CODE_REMAINS_F1_UNTIL_PREEMPTION_EDGE",
                fault_active &&
                (fault_code == 2'b01)
            );


            /*
             * ========================================================
             * STEP 5 — manager consumes F2 pulse
             * ========================================================
             */
            @(posedge clk);
            #2;


            check(
                "F12_F1_REPLACED_BY_F2",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "F12_F2_RECLASSIFICATION_SEEN",
                f2_reclassification_seen != 0
            );

            check(
                "F12_RECOVERY_REMAINS_ACTIVE_ACROSS_HANDOFF",
                recovery_active == 1'b1
            );

            check(
                "F12_COMMANDS_REMAIN_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "F12_RECOVERY_OWNERSHIP_RETAINED",
                recovery_owns_bus == 1'b1
            );

            check(
                "F12_PREEMPTION_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "F12_PREEMPTION_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );

            check(
                "F12_NO_SYNTHETIC_BUSY_HOLD",
                fault_busy_hold == 1'b0
            );

            check(
                "F12_NO_SYNTHETIC_DONE",
                fault_done_count == 0
            );

            check(
                "F12_NO_SECOND_CORE_ABORT",
                fault_abort_count == 1
            );

            check(
                "F12_FIRST_F1_CLOCK_WAS_NOT_COMPLETED",
                dut.recovery_pulse_count == 4'd0
            );

            check(
                "F12_ONLY_ONE_F1_LOW_PULSE_BEFORE_PREEMPTION",
                recovery_scl_low_pulse_count == 1
            );

            check(
                "F12_NO_POST_F2_SCL_LOW_DRIVE",
                post_f2_scl_low_violation_count == 0
            );

            check(
                "F12_NO_SDA_LOW_DRIVE",
                recovery_sda_low_violation_count == 0
            );


            /*
             * ========================================================
             * STEP 6 — extended F2 containment
             * ========================================================
             *
             * Keep both external faults present.
             *
             * SDA is still LOW from the original F1 condition.
             * SCL is still LOW from the compound F2 condition.
             */
            wait_cycles(
                F2_LIMIT + 8
            );


            check(
                "F12_EXTENDED_F2_CONTAINMENT_ACTIVE",
                recovery_active == 1'b1
            );

            check(
                "F12_EXTENDED_F2_OWNS_BUS",
                recovery_owns_bus == 1'b1
            );

            check(
                "F12_EXTENDED_F2_COMMANDS_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "F12_EXTENDED_F2_CODE_STAYS_SCL_STALL",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "F12_EXTENDED_F2_PHYSICAL_SCL_LOW",
                scl_in == 1'b0
            );

            check(
                "F12_EXTENDED_F2_CONTROLLER_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "F12_EXTENDED_F2_CONTROLLER_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );

            check(
                "F12_EXTENDED_F2_NO_EXTRA_F1_CLOCKS",
                recovery_scl_low_pulse_count == 1
            );

            check(
                "F12_EXTENDED_F2_NO_SECOND_ABORT",
                fault_abort_count == 1
            );

            check(
                "F12_EXTENDED_F2_NO_DONE",
                fault_done_count == 0
            );


            /*
             * ========================================================
             * STEP 7 — release SCL, leave SDA LOW
             * ========================================================
             *
             * F2 must leave the SCL-release wait but must not complete
             * containment because the complete electrical bus-free
             * condition is still false.
             */
            @(negedge clk);

            ext_scl_hold_low = 1'b0;

            wait_cycles(6);


            check(
                "F12_EXTERNAL_SCL_RELEASED_HIGH",
                scl_in == 1'b1
            );

            check(
                "F12_ORIGINAL_SDA_FAULT_STILL_LOW",
                sda_in == 1'b0
            );

            check(
                "F12_SDA_LOW_PREVENTS_RETURN_TO_SERVICE",
                recovery_active == 1'b1
            );

            check(
                "F12_SDA_LOW_KEEPS_COMMANDS_BLOCKED",
                block_cmd_ready == 1'b1
            );

            check(
                "F12_SDA_LOW_NO_BUSY_HOLD",
                fault_busy_hold == 1'b0
            );

            check(
                "F12_SDA_LOW_NO_DONE",
                fault_done_count == 0
            );


            /*
             * ========================================================
             * STEP 8 — finally release SDA and qualify continuous tBUF
             * ========================================================
             */
            @(negedge clk);

            ext_sda_hold_low = 1'b0;

            final_bus_free_time = $time;


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
                        "Timed out waiting for F1-to-F2 containment completion"
                    );

                end

            end

            containment_complete_time = $time;


            check(
                "F12_TBUF_COMPLETES_BEFORE_RETURN_TO_SERVICE",
                (
                    containment_complete_time -
                    final_bus_free_time
                ) >=
                (
                    T_BUF_CYCLES *
                    CLK_PERIOD_NS
                )
            );

            check(
                "F12_RETURN_TO_SERVICE",
                !recovery_active &&
                !recovery_owns_bus &&
                !block_cmd_ready
            );

            check(
                "F12_FINAL_FAULT_CODE_REMAINS_F2",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "F12_RECOVERY_FAILED_REMAINS_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "F12_COMPOUND_CASE_NEVER_ASSERTED_BUSY",
                fault_busy_hold == 1'b0
            );

            check(
                "F12_COMPOUND_CASE_GENERATES_NO_DONE",
                fault_done_count == 0
            );

            check(
                "F12_COMPOUND_CASE_ONLY_ONE_ABORT",
                fault_abort_count == 1
            );

            check(
                "F12_NO_EXTRA_F1_CLOCKS_AFTER_PREEMPTION",
                recovery_scl_low_pulse_count == 1
            );

            check(
                "F12_NO_POST_F2_SCL_LOW_VIOLATION",
                post_f2_scl_low_violation_count == 0
            );

            check(
                "F12_NO_SDA_LOW_VIOLATION",
                recovery_sda_low_violation_count == 0
            );


            /*
             * Remain idle for several cycles.
             *
             * This proves that the abandoned F1 operation is not
             * automatically restarted and no delayed synthetic command
             * completion appears.
             */
            wait_cycles(8);


            check(
                "F12_NO_AUTOMATIC_F1_RESTART",
                recovery_scl_low_pulse_count == 1
            );

            check(
                "F12_NO_DELAYED_DONE",
                fault_done_count == 0
            );

            check(
                "F12_STATUS_PERSISTS_AS_SCL_STALL",
                fault_active &&
                (fault_code == 2'b10)
            );


            /*
             * ========================================================
             * STEP 9 — next accepted command clears historical status
             * ========================================================
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
                "F12_NEXT_COMMAND_CLEARS_FAULT_ACTIVE",
                fault_active == 1'b0
            );

            check(
                "F12_NEXT_COMMAND_CLEARS_FAULT_CODE",
                fault_code == 2'b00
            );

            check(
                "F12_STATUS_CLEAR_CREATES_NO_DONE",
                fault_done_count == 0
            );

            check(
                "F12_STATUS_CLEAR_CREATES_NO_BUSY",
                fault_busy_hold == 1'b0
            );


            scenario_enable = 1'b0;

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
            "S6.3E F1-to-F2 preemption unit-test watchdog expired"
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

        scenario_enable = 1'b0;

        rst_n = 1'b0;

        cmd_accept = 1'b0;

        core_expect_bus_free = 1'b0;
        core_waiting_for_scl_high = 1'b0;
        core_transaction_active = 1'b0;
        core_scl_drive_low = 1'b0;

        ext_sda_hold_low = 1'b0;
        ext_scl_hold_low = 1'b0;


        test_f1_to_f2_preemption();


        $display("");
        $display(
            "============================================"
        );

        if (error_count == 0) begin

            $display(
                "S6.3E F1 TO F2 PREEMPTION UNIT TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

        end
        else begin

            $display(
                "S6.3E F1 TO F2 PREEMPTION UNIT TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $fatal(
                1,
                "S6.3E F1-to-F2 preemption verification failed"
            );

        end

        $display(
            "============================================"
        );

        $finish;

    end

endmodule