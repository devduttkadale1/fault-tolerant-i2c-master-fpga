`timescale 1ns/1ps

module tb_baseline_start_timing_stretch;

    localparam integer SYS_CLK_HZ = 100_000_000;
    localparam integer I2C_CLK_HZ = 100_000;

    localparam integer HALF_PERIOD_CYCLES = 500;
    localparam integer STRETCH_CYCLES     = 100;

    logic clk;
    logic rst_n;

    logic       cmd_valid;
    logic       cmd_ready;
    logic       cmd_rw;
    logic [6:0] cmd_addr;
    logic [7:0] cmd_wdata;

    logic [7:0] read_data;
    logic       busy;
    logic       done;
    logic       nack;

    logic sda_drive_low;
    logic scl_drive_low;

    logic target_scl_hold_low;

    wire sda_bus;
    wire scl_bus;

    integer error_count;

    time start_time;
    time low_start_time;
    time controller_release_time;
    time high_start_time;
    time high_end_time;

    /*
     * Simple open-drain bus model for this timing test.
     */
    assign sda_bus =
        sda_drive_low ? 1'b0 : 1'b1;

    assign scl_bus =
        (scl_drive_low || target_scl_hold_low) ?
        1'b0 :
        1'b1;

    i2c_master_baseline #(
        .SYS_CLK_HZ (SYS_CLK_HZ),
        .I2C_CLK_HZ (I2C_CLK_HZ)
    ) dut (
        .clk           (clk),
        .rst_n         (rst_n),

        .cmd_valid     (cmd_valid),
        .cmd_ready     (cmd_ready),
        .cmd_rw        (cmd_rw),
        .cmd_addr      (cmd_addr),
        .cmd_wdata     (cmd_wdata),

        .read_data     (read_data),
        .busy          (busy),
        .done          (done),
        .nack          (nack),

        .sda_in        (sda_bus),
        .scl_in        (scl_bus),

        .sda_drive_low (sda_drive_low),
        .scl_drive_low (scl_drive_low)
    );

    always #5 clk = ~clk;

    task automatic check(
        input string name,
        input logic condition
    );
        if (condition) begin

            $display("[PASS] %s", name);

        end
        else begin

            $error("[FAIL] %s", name);
            error_count++;

        end
    endtask

    initial begin

        clk                 = 1'b0;
        rst_n               = 1'b0;

        cmd_valid           = 1'b0;
        cmd_rw              = 1'b0;
        cmd_addr            = 7'h50;
        cmd_wdata           = 8'hA5;

        target_scl_hold_low = 1'b0;

        error_count         = 0;

        /*
         * ------------------------------------------------------------
         * RESET
         * ------------------------------------------------------------
         */

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        /*
         * Wait for full tBUF qualification.
         */
        wait (cmd_ready === 1'b1);

        check(
            "BUS_READY_BEFORE_COMMAND",
            cmd_ready == 1'b1
        );

        /*
         * ------------------------------------------------------------
         * ISSUE WRITE COMMAND
         * ------------------------------------------------------------
         */

        @(negedge clk);
        cmd_valid = 1'b1;

        /*
         * START must be SDA HIGH->LOW while SCL remains HIGH.
         */
        @(negedge sda_bus);

        start_time = $time;

        #1;

        check(
            "START_SDA_FALLS_WHILE_SCL_HIGH",
            scl_bus == 1'b1
        );

        /*
         * Command is now active.
         */
        @(posedge clk);
        #1;

        check(
            "COMMAND_ACTIVE_BUSY",
            busy == 1'b1
        );

        @(negedge clk);
        cmd_valid = 1'b0;

        /*
         * ------------------------------------------------------------
         * START HOLD -> FIRST SCL LOW
         * ------------------------------------------------------------
         */

        @(negedge scl_bus);

        low_start_time = $time;

        check(
            "START_HOLD_AT_LEAST_5US",
            (low_start_time - start_time) >= 5000
        );

        #1;

        /*
         * 0x50 + WRITE creates address byte 0xA0.
         * MSB is therefore 1 and SDA must be released.
         */
        check(
            "FIRST_ADDRESS_BIT_IS_ONE",
            sda_bus == 1'b1
        );

        /*
         * Target begins a legal stretch while the controller is still
         * producing the first address-bit LOW interval.
         */
        @(negedge clk);
        target_scl_hold_low = 1'b1;

        /*
         * Wait for controller to finish its own LOW interval and release
         * SCL.
         */
        @(negedge scl_drive_low);

        controller_release_time = $time;

        #1;

        check(
            "SCL_LOW_AT_LEAST_5US",
            (controller_release_time - low_start_time) >= 5000
        );

        check(
            "CONTROLLER_RELEASES_SCL",
            scl_drive_low == 1'b0
        );

        check(
            "BUS_REMAINS_LOW_DURING_STRETCH",
            scl_bus == 1'b0
        );

        check(
            "WAITING_FOR_ACTUAL_SCL_HIGH",
            dut.core_waiting_for_scl_high == 1'b1
        );

        /*
         * ------------------------------------------------------------
         * LEGAL CLOCK STRETCH
         * ------------------------------------------------------------
         */

        repeat (STRETCH_CYCLES) @(posedge clk);
        #1;

        check(
            "NO_PROGRESS_WHILE_TARGET_HOLDS_SCL",
            scl_bus == 1'b0
        );

        check(
            "CONTROLLER_DOES_NOT_FORCE_SCL_HIGH",
            scl_drive_low == 1'b0
        );

        check(
            "STILL_WAITING_DURING_STRETCH",
            dut.core_waiting_for_scl_high == 1'b1
        );

        /*
         * Release external clock stretch between DUT sampling edges.
         */
        @(negedge clk);

        high_start_time = $time;
        target_scl_hold_low = 1'b0;

        #1;

        check(
            "SCL_RISES_AFTER_TARGET_RELEASE",
            scl_bus == 1'b1
        );

        /*
         * DUT observes actual SCL HIGH at the following rising clock.
         */
        @(posedge clk);
        #1;

        check(
            "WAITING_CLEARS_AFTER_ACTUAL_HIGH",
            dut.core_waiting_for_scl_high == 1'b0
        );

        /*
         * ------------------------------------------------------------
         * HIGH TIMING
         * ------------------------------------------------------------
         *
         * Stretch time must not consume the required SCL HIGH interval.
         */

        @(negedge scl_bus);

        high_end_time = $time;

        check(
            "SCL_HIGH_AT_LEAST_5US_AFTER_STRETCH",
            (high_end_time - high_start_time) >= 5000
        );

        check(
            "TRANSACTION_STILL_ACTIVE",
            busy == 1'b1
        );

        /*
         * Seeing this next falling edge proves the timing engine resumed
         * rather than deadlocking after the stretch.
         */
        check(
            "NO_DEADLOCK_AFTER_STRETCH_RELEASE",
            scl_drive_low == 1'b1
        );

        /*
         * ------------------------------------------------------------
         * FINAL RESULT
         * ------------------------------------------------------------
         */

        if (error_count == 0) begin

            $display("");
            $display("===========================================");
            $display("S5.2B START/TIMING/STRETCH TEST : PASS");
            $display("ERROR COUNT = %0d", error_count);
            $display("===========================================");

        end
        else begin

            $fatal(
                1,
                "S5.2B TEST FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule