`timescale 1ns/1ps

module tb_i2c_fault_detector;

    /*
     * ================================================================
     * Small simulation thresholds
     * ================================================================
     *
     * Production defaults:
     *   F1 = 10,000 cycles
     *   F2 = 100,000 cycles
     *
     * This focused unit test intentionally uses smaller values so that
     * exact LIMIT-1 / LIMIT behavior can be checked quickly.
     */
    localparam integer F1_LIMIT = 4;
    localparam integer F2_LIMIT = 5;

    logic clk;
    logic rst_n;

    logic f1_monitor_enable;
    logic f2_monitor_enable;

    logic expect_bus_free;
    logic waiting_for_scl_high;
    logic scl_drive_low;

    logic sda_in;
    logic scl_in;

    logic f1_detect_pulse;
    logic f2_detect_pulse;

    integer error_count;


    /*
     * ================================================================
     * DUT
     * ================================================================
     */
    i2c_fault_detector #(
        .SDA_STUCK_LIMIT_CYCLES (F1_LIMIT),
        .SCL_STALL_LIMIT_CYCLES (F2_LIMIT)
    ) dut (
        .clk                  (clk),
        .rst_n                (rst_n),

        .f1_monitor_enable    (f1_monitor_enable),
        .f2_monitor_enable    (f2_monitor_enable),

        .expect_bus_free      (expect_bus_free),
        .waiting_for_scl_high (waiting_for_scl_high),
        .scl_drive_low        (scl_drive_low),

        .sda_in               (sda_in),
        .scl_in               (scl_in),

        .f1_detect_pulse      (f1_detect_pulse),
        .f2_detect_pulse      (f2_detect_pulse)
    );


    /*
     * ================================================================
     * 100 MHz system clock
     * ================================================================
     */
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
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
     * Return detector inputs to a benign state
     * ================================================================
     */
    task automatic drive_idle;
        begin

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;

            sda_in               = 1'b1;
            scl_in               = 1'b1;

            @(posedge clk);
            #1;

            check(
                "IDLE_NO_F1_PULSE",
                f1_detect_pulse == 1'b0
            );

            check(
                "IDLE_NO_F2_PULSE",
                f2_detect_pulse == 1'b0
            );

        end
    endtask


    /*
     * ================================================================
     * F1 exact boundary
     * ================================================================
     */
    task automatic test_f1_exact_boundary;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F1 EXACT LIMIT-1 / LIMIT ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b1;
            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;

            scl_in               = 1'b1;
            sda_in               = 1'b0;

            /*
             * Samples 1 through LIMIT-1 must not detect.
             */
            for (i = 1; i < F1_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    $sformatf(
                        "F1_NO_DETECT_SAMPLE_%0d",
                        i
                    ),
                    f1_detect_pulse == 1'b0
                );

                check(
                    "F1_BOUNDARY_NO_F2",
                    f2_detect_pulse == 1'b0
                );

            end

            /*
             * Sample LIMIT must detect.
             */
            @(posedge clk);
            #1;

            check(
                "F1_DETECT_EXACTLY_AT_LIMIT",
                f1_detect_pulse == 1'b1
            );

            check(
                "F1_DETECTION_DOES_NOT_ASSERT_F2",
                f2_detect_pulse == 1'b0
            );

            /*
             * Continued stuck condition must not produce another
             * detection pulse.
             */
            @(posedge clk);
            #1;

            check(
                "F1_NO_REPEATED_PULSE_WHILE_STILL_STUCK",
                f1_detect_pulse == 1'b0
            );

            /*
             * Remove qualification to re-arm.
             */
            @(negedge clk);
            sda_in = 1'b1;

            @(posedge clk);
            #1;

            check(
                "F1_REARM_AFTER_CONDITION_CLEARS",
                f1_detect_pulse == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * F1 must not count protocol SDA LOW when bus free is not expected
     * ================================================================
     */
    task automatic test_f1_context_filter;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F1 CONTEXT FILTER ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;

            scl_in               = 1'b1;
            sda_in               = 1'b0;

            /*
             * Hold SDA LOW longer than the threshold.
             * Because expect_bus_free=0, this is protocol activity,
             * not F1.
             */
            for (i = 0; i < (F1_LIMIT + 2); i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F1_NOT_TRIGGERED_DURING_PROTOCOL_ACTIVITY",
                    f1_detect_pulse == 1'b0
                );

            end

            @(negedge clk);
            sda_in = 1'b1;

        end

    endtask


    /*
     * ================================================================
     * F1 broken persistence sequence must reset the counter
     * ================================================================
     */
    task automatic test_f1_counter_reset;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F1 COUNTER RESET ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b1;
            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;

            scl_in               = 1'b1;
            sda_in               = 1'b0;

            /*
             * Two qualifying samples.
             */
            repeat (2) begin

                @(posedge clk);
                #1;

                check(
                    "F1_PARTIAL_SEQUENCE_NO_DETECT",
                    f1_detect_pulse == 1'b0
                );

            end

            /*
             * Break qualification.
             */
            @(negedge clk);
            sda_in = 1'b1;

            @(posedge clk);
            #1;

            check(
                "F1_COUNTER_RESET_ON_QUALIFICATION_LOSS",
                f1_detect_pulse == 1'b0
            );

            /*
             * Begin a new sequence. LIMIT-1 samples must again be
             * insufficient.
             */
            @(negedge clk);
            sda_in = 1'b0;

            for (i = 1; i < F1_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F1_AFTER_RESET_STILL_BELOW_LIMIT",
                    f1_detect_pulse == 1'b0
                );

            end

            @(posedge clk);
            #1;

            check(
                "F1_AFTER_RESET_DETECTS_AT_NEW_LIMIT",
                f1_detect_pulse == 1'b1
            );

            @(negedge clk);
            sda_in = 1'b1;

        end

    endtask


    /*
     * ================================================================
     * F1 enable removal must clear partial persistence
     * ================================================================
     */
    task automatic test_f1_monitor_disable_reset;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F1 MONITOR DISABLE RESET ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b1;
            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;

            scl_in               = 1'b1;
            sda_in               = 1'b0;

            repeat (2) begin

                @(posedge clk);
                #1;

                check(
                    "F1_PRE_DISABLE_PARTIAL_NO_DETECT",
                    f1_detect_pulse == 1'b0
                );

            end

            /*
             * Disable F1 monitoring while the electrical condition
             * remains present.
             */
            @(negedge clk);
            f1_monitor_enable = 1'b0;

            @(posedge clk);
            #1;

            check(
                "F1_DISABLED_NO_DETECT",
                f1_detect_pulse == 1'b0
            );

            /*
             * Re-enable. A complete new threshold must be required.
             */
            @(negedge clk);
            f1_monitor_enable = 1'b1;

            for (i = 1; i < F1_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F1_REENABLE_REQUIRES_FRESH_THRESHOLD",
                    f1_detect_pulse == 1'b0
                );

            end

            @(posedge clk);
            #1;

            check(
                "F1_REENABLE_DETECTS_AT_FRESH_LIMIT",
                f1_detect_pulse == 1'b1
            );

            @(negedge clk);
            sda_in = 1'b1;

        end

    endtask


    /*
     * ================================================================
     * F2 intentional controller SCL LOW must be excluded
     * ================================================================
     */
    task automatic test_f2_intentional_low_filter;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 INTENTIONAL SCL LOW FILTER ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b1;

            /*
             * Controller itself intentionally drives SCL LOW.
             */
            scl_drive_low        = 1'b1;

            sda_in               = 1'b1;
            scl_in               = 1'b0;

            for (i = 0; i < (F2_LIMIT + 2); i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F2_NOT_TRIGGERED_WHILE_CONTROLLER_DRIVES_SCL_LOW",
                    f2_detect_pulse == 1'b0
                );

            end

            @(negedge clk);

            waiting_for_scl_high = 1'b0;
            scl_drive_low        = 1'b0;
            scl_in               = 1'b1;

        end

    endtask


    /*
     * ================================================================
     * Legal short clock stretching
     * ================================================================
     */
    task automatic test_f2_legal_short_stretch;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 LEGAL SHORT STRETCH ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b1;
            scl_drive_low        = 1'b0;

            sda_in               = 1'b1;
            scl_in               = 1'b0;

            /*
             * Exactly LIMIT-1 qualifying samples are legal for this
             * implementation-defined threshold.
             */
            for (i = 1; i < F2_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    $sformatf(
                        "F2_NO_DETECT_SAMPLE_%0d",
                        i
                    ),
                    f2_detect_pulse == 1'b0
                );

            end

            /*
             * Target releases SCL before sample LIMIT.
             */
            @(negedge clk);
            scl_in = 1'b1;

            @(posedge clk);
            #1;

            check(
                "LEGAL_SHORT_STRETCH_NO_F2",
                f2_detect_pulse == 1'b0
            );

            @(negedge clk);
            waiting_for_scl_high = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F2 exact boundary and one-shot behavior
     * ================================================================
     */
    task automatic test_f2_exact_boundary;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 EXACT LIMIT-1 / LIMIT ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b1;
            scl_drive_low        = 1'b0;

            sda_in               = 1'b1;
            scl_in               = 1'b0;

            for (i = 1; i < F2_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F2_BELOW_LIMIT_NO_DETECT",
                    f2_detect_pulse == 1'b0
                );

            end

            @(posedge clk);
            #1;

            check(
                "F2_DETECT_EXACTLY_AT_LIMIT",
                f2_detect_pulse == 1'b1
            );

            check(
                "F2_DETECTION_DOES_NOT_ASSERT_F1",
                f1_detect_pulse == 1'b0
            );

            /*
             * Persistent SCL LOW must not produce repeated pulses.
             */
            @(posedge clk);
            #1;

            check(
                "F2_NO_REPEATED_PULSE_WHILE_STALL_PERSISTS",
                f2_detect_pulse == 1'b0
            );

            @(negedge clk);

            scl_in               = 1'b1;
            waiting_for_scl_high = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * F2 monitoring must also work when F1 monitoring is disabled.
     *
     * This models the context required while an F1 recovery controller
     * has bus ownership and is waiting for released SCL to rise.
     * ================================================================
     */
    task automatic test_f2_during_f1_recovery_context;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 DURING F1 RECOVERY CONTEXT ====="
            );

            @(negedge clk);

            /*
             * F1 detector disabled because F1 handling is already
             * active. F2 remains enabled for SCL-loss-of-progress
             * classification.
             */
            f1_monitor_enable    = 1'b0;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b1;
            scl_drive_low        = 1'b0;

            sda_in               = 1'b1;
            scl_in               = 1'b0;

            for (i = 1; i < F2_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F2_RECOVERY_CONTEXT_BELOW_LIMIT",
                    f2_detect_pulse == 1'b0
                );

            end

            @(posedge clk);
            #1;

            check(
                "F2_RECOVERY_CONTEXT_DETECTS_AT_LIMIT",
                f2_detect_pulse == 1'b1
            );

            check(
                "F1_DISABLED_DURING_RECOVERY_CONTEXT",
                f1_detect_pulse == 1'b0
            );

            @(negedge clk);

            scl_in               = 1'b1;
            waiting_for_scl_high = 1'b0;

            f1_monitor_enable    = 1'b1;

        end

    endtask


    /*
     * ================================================================
     * F2 monitor disable clears partial persistence
     * ================================================================
     */
    task automatic test_f2_monitor_disable_reset;

        integer i;

        begin

            $display("");
            $display(
                "===== TEST F2 MONITOR DISABLE RESET ====="
            );

            @(negedge clk);

            f1_monitor_enable    = 1'b1;
            f2_monitor_enable    = 1'b1;

            expect_bus_free      = 1'b0;
            waiting_for_scl_high = 1'b1;
            scl_drive_low        = 1'b0;

            sda_in               = 1'b1;
            scl_in               = 1'b0;

            repeat (2) begin

                @(posedge clk);
                #1;

                check(
                    "F2_PRE_DISABLE_PARTIAL_NO_DETECT",
                    f2_detect_pulse == 1'b0
                );

            end

            @(negedge clk);
            f2_monitor_enable = 1'b0;

            @(posedge clk);
            #1;

            check(
                "F2_DISABLED_NO_DETECT",
                f2_detect_pulse == 1'b0
            );

            @(negedge clk);
            f2_monitor_enable = 1'b1;

            for (i = 1; i < F2_LIMIT; i = i + 1) begin

                @(posedge clk);
                #1;

                check(
                    "F2_REENABLE_REQUIRES_FRESH_THRESHOLD",
                    f2_detect_pulse == 1'b0
                );

            end

            @(posedge clk);
            #1;

            check(
                "F2_REENABLE_DETECTS_AT_FRESH_LIMIT",
                f2_detect_pulse == 1'b1
            );

            @(negedge clk);

            scl_in               = 1'b1;
            waiting_for_scl_high = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Watchdog
     * ================================================================
     */
    initial begin

        #1_000_000;

        $fatal(
            1,
            "S6.2B detector test watchdog expired"
        );

    end


    /*
     * ================================================================
     * Main test sequence
     * ================================================================
     */
    initial begin

        error_count = 0;

        rst_n = 1'b0;

        f1_monitor_enable    = 1'b0;
        f2_monitor_enable    = 1'b0;

        expect_bus_free      = 1'b0;
        waiting_for_scl_high = 1'b0;
        scl_drive_low        = 1'b0;

        sda_in = 1'b1;
        scl_in = 1'b1;


        /*
         * Reset.
         */
        repeat (4) begin
            @(posedge clk);
        end

        @(negedge clk);
        rst_n = 1'b1;

        @(posedge clk);
        #1;

        check(
            "RESET_F1_PULSE_CLEAR",
            f1_detect_pulse == 1'b0
        );

        check(
            "RESET_F2_PULSE_CLEAR",
            f2_detect_pulse == 1'b0
        );


        drive_idle();

        test_f1_context_filter();
        drive_idle();

        test_f1_exact_boundary();
        drive_idle();

        test_f1_counter_reset();
        drive_idle();

        test_f1_monitor_disable_reset();
        drive_idle();

        test_f2_intentional_low_filter();
        drive_idle();

        test_f2_legal_short_stretch();
        drive_idle();

        test_f2_exact_boundary();
        drive_idle();

        test_f2_during_f1_recovery_context();
        drive_idle();

        test_f2_monitor_disable_reset();
        drive_idle();


        /*
         * ============================================================
         * Final result
         * ============================================================
         */
        $display("");
        $display(
            "============================================"
        );

        if (error_count == 0) begin

            $display(
                "S6.2B FAULT DETECTOR BOUNDARY TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

        end
        else begin

            $display(
                "S6.2B FAULT DETECTOR BOUNDARY TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $fatal(
                1,
                "S6.2B detector verification failed"
            );

        end

        $display(
            "============================================"
        );

        $finish;

    end

endmodule