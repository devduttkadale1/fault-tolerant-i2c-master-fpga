`timescale 1ns/1ps

module tb_i2c_fault_metrics_production;

    /*
     * ================================================================
     * Production-policy confirmation configuration
     * ================================================================
     *
     * These are the frozen project parameters:
     *
     *   system clock : 100 MHz
     *   I2C clock    : 100 kHz nominal
     *   F1 limit     : 10,000 qualifying samples
     *   F2 limit     : 100,000 qualifying samples
     *
     * These timeout values are project policy, not I2C specification
     * maximum timing requirements.
     */
    localparam integer SYS_CLK_HZ = 100_000_000;
    localparam integer I2C_CLK_HZ = 100_000;

    localparam integer F1_LIMIT = 10_000;
    localparam integer F2_LIMIT = 100_000;

    localparam integer CLK_PERIOD_NS =
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
     * Verification metrics
     * ================================================================
     */
    integer error_count;
    integer production_row_count;

    integer cycle_count;

    integer fault_onset_cycle;
    integer detect_cycle;
    integer manager_response_cycle;

    integer detection_latency_cycles;
    integer manager_response_cycles;

    integer detection_latency_ns;
    integer manager_response_ns;

    integer early_detect_count;


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
     * Open-drain bus model
     * ================================================================
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
                    ext_scl_hold_low ||
                    recovery_scl_drive_low
                ) ?
                1'b0 :
                1'b1;

        end
        else begin

            scl_in =
                (
                    ext_scl_hold_low ||
                    core_scl_drive_low
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
     * Production evidence row
     * ================================================================
     *
     * Columns:
     *
     * test_id
     * result
     * fault_code
     * sys_clk_hz
     * i2c_clk_hz
     * threshold_cycles
     * fault_onset_cycle
     * detect_cycle
     * detection_latency_cycles
     * detection_latency_ns
     * manager_response_cycle
     * manager_response_cycles
     * manager_response_ns
     */
    task automatic emit_production_row(
        input string  test_id,
        input integer row_pass,
        input integer row_fault_code,
        input integer row_threshold_cycles
    );

        string result_text;

        begin

            if (row_pass != 0) begin
                result_text = "PASS";
            end
            else begin
                result_text = "FAIL";
            end


            $display(
                "S7PRODROW,%s,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
                test_id,
                result_text,
                row_fault_code,
                SYS_CLK_HZ,
                I2C_CLK_HZ,
                row_threshold_cycles,
                fault_onset_cycle,
                detect_cycle,
                detection_latency_cycles,
                detection_latency_ns,
                manager_response_cycle,
                manager_response_cycles,
                manager_response_ns
            );


            production_row_count =
                production_row_count + 1;

        end

    endtask


    /*
     * ================================================================
     * Reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            rst_n = 1'b0;

            cmd_accept = 1'b0;

            core_expect_bus_free = 1'b0;
            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b0;
            ext_scl_hold_low = 1'b0;

            fault_onset_cycle = -1;
            detect_cycle = -1;
            manager_response_cycle = -1;

            detection_latency_cycles = -1;
            manager_response_cycles = -1;

            detection_latency_ns = -1;
            manager_response_ns = -1;

            early_detect_count = 0;


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
     * Production F1 threshold confirmation
     * ================================================================
     */
    task automatic test_f1_production_threshold;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 PRODUCTION F1 THRESHOLD ====="
            );

            reset_dut();

            errors_before = error_count;


            @(negedge clk);

            core_expect_bus_free = 1'b1;
            core_waiting_for_scl_high = 1'b0;
            core_transaction_active = 1'b0;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b1;
            ext_scl_hold_low = 1'b0;


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

                    if (
                        dut.f1_detect_pulse ||
                        fault_active
                    ) begin

                        early_detect_count =
                            early_detect_count + 1;

                    end

                end
                else begin

                    check(
                        "PROD_F1_DETECT_EXACTLY_AT_LIMIT",
                        dut.f1_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            detection_latency_cycles =
                detect_cycle -
                fault_onset_cycle;

            detection_latency_ns =
                detection_latency_cycles *
                CLK_PERIOD_NS;


            check(
                "PROD_F1_NO_EARLY_DETECTION",
                early_detect_count == 0
            );

            check(
                "PROD_F1_DETECTION_LATENCY_9999_CYCLES",
                detection_latency_cycles ==
                (F1_LIMIT - 1)
            );

            check(
                "PROD_F1_DETECTION_LATENCY_99990_NS",
                detection_latency_ns == 99_990
            );


            /*
             * Detector pulse is consumed by the manager on the following
             * system-clock edge.
             */
            @(posedge clk);
            #1;


            manager_response_cycle =
                cycle_count;

            manager_response_cycles =
                manager_response_cycle -
                fault_onset_cycle;

            manager_response_ns =
                manager_response_cycles *
                CLK_PERIOD_NS;


            check(
                "PROD_F1_MANAGER_LATCHES_FAULT",
                fault_active == 1'b1
            );

            check(
                "PROD_F1_MANAGER_CODE_SDA_STUCK",
                fault_code == 2'b01
            );

            check(
                "PROD_F1_MANAGER_BLOCKS_COMMANDS",
                block_cmd_ready == 1'b1
            );

            check(
                "PROD_F1_MANAGER_RESPONSE_10000_CYCLES",
                manager_response_cycles ==
                F1_LIMIT
            );

            check(
                "PROD_F1_MANAGER_RESPONSE_100000_NS",
                manager_response_ns ==
                100_000
            );


            emit_production_row(
                "F1_PRODUCTION_THRESHOLD",
                (error_count == errors_before),
                1,
                F1_LIMIT
            );

        end

    endtask


    /*
     * ================================================================
     * Production F2 threshold confirmation
     * ================================================================
     */
    task automatic test_f2_production_threshold;

        integer i;
        integer errors_before;

        begin

            $display("");
            $display(
                "===== S7 PRODUCTION F2 THRESHOLD ====="
            );

            reset_dut();

            errors_before = error_count;


            @(negedge clk);

            core_expect_bus_free = 1'b0;
            core_waiting_for_scl_high = 1'b1;
            core_transaction_active = 1'b1;
            core_scl_drive_low = 1'b0;

            ext_sda_hold_low = 1'b0;
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

                    if (
                        dut.f2_detect_pulse ||
                        fault_active
                    ) begin

                        early_detect_count =
                            early_detect_count + 1;

                    end

                end
                else begin

                    check(
                        "PROD_F2_DETECT_EXACTLY_AT_LIMIT",
                        dut.f2_detect_pulse == 1'b1
                    );

                    detect_cycle =
                        cycle_count;

                end

            end


            detection_latency_cycles =
                detect_cycle -
                fault_onset_cycle;

            detection_latency_ns =
                detection_latency_cycles *
                CLK_PERIOD_NS;


            check(
                "PROD_F2_NO_EARLY_DETECTION",
                early_detect_count == 0
            );

            check(
                "PROD_F2_DETECTION_LATENCY_99999_CYCLES",
                detection_latency_cycles ==
                (F2_LIMIT - 1)
            );

            check(
                "PROD_F2_DETECTION_LATENCY_999990_NS",
                detection_latency_ns == 999_990
            );


            /*
             * Manager consumes the F2 detector pulse on the following edge.
             */
            @(posedge clk);
            #1;


            manager_response_cycle =
                cycle_count;

            manager_response_cycles =
                manager_response_cycle -
                fault_onset_cycle;

            manager_response_ns =
                manager_response_cycles *
                CLK_PERIOD_NS;


            check(
                "PROD_F2_MANAGER_LATCHES_FAULT",
                fault_active == 1'b1
            );

            check(
                "PROD_F2_MANAGER_CODE_SCL_STALL",
                fault_code == 2'b10
            );

            check(
                "PROD_F2_MANAGER_TAKES_OWNERSHIP",
                recovery_owns_bus == 1'b1
            );

            check(
                "PROD_F2_MANAGER_RELEASES_SCL",
                recovery_scl_drive_low == 1'b0
            );

            check(
                "PROD_F2_MANAGER_RELEASES_SDA",
                recovery_sda_drive_low == 1'b0
            );

            check(
                "PROD_F2_MANAGER_RESPONSE_100000_CYCLES",
                manager_response_cycles ==
                F2_LIMIT
            );

            check(
                "PROD_F2_MANAGER_RESPONSE_1000000_NS",
                manager_response_ns ==
                1_000_000
            );


            emit_production_row(
                "F2_PRODUCTION_THRESHOLD",
                (error_count == errors_before),
                2,
                F2_LIMIT
            );

        end

    endtask


    /*
     * ================================================================
     * Watchdog
     * ================================================================
     */
    initial begin

        #10_000_000;

        $fatal(
            1,
            "S7.6B PRODUCTION LATENCY WATCHDOG: simulation did not finish"
        );

    end


    /*
     * ================================================================
     * Main
     * ================================================================
     */
    initial begin

        rst_n = 1'b0;

        cmd_accept = 1'b0;

        core_expect_bus_free = 1'b0;
        core_waiting_for_scl_high = 1'b0;
        core_transaction_active = 1'b0;
        core_scl_drive_low = 1'b0;

        ext_sda_hold_low = 1'b0;
        ext_scl_hold_low = 1'b0;

        error_count = 0;
        production_row_count = 0;

        cycle_count = 0;


        test_f1_production_threshold();
        test_f2_production_threshold();


        check(
            "PRODUCTION_ROW_COUNT_TWO",
            production_row_count == 2
        );


        $display("");
        $display(
            "============================================"
        );


        if (
            (error_count == 0) &&
            (production_row_count == 2)
        ) begin

            $display(
                "S7.6B PRODUCTION LATENCY CONFIRMATION : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

            $display(
                "PRODUCTION ROW COUNT = 2"
            );

        end
        else begin

            $display(
                "S7.6B PRODUCTION LATENCY CONFIRMATION : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $display(
                "PRODUCTION ROW COUNT = %0d",
                production_row_count
            );

            $fatal(
                1,
                "Production-policy latency confirmation failed"
            );

        end


        $display(
            "============================================"
        );

        $finish;

    end

endmodule