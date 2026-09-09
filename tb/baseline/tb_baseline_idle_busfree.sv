`timescale 1ns/1ps

module tb_baseline_idle_busfree;

    localparam integer SYS_CLK_HZ = 100_000_000;
    localparam integer I2C_CLK_HZ = 100_000;

    localparam integer T_BUF_CYCLES = 470;

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

    logic sda_in;
    logic scl_in;

    logic sda_drive_low;
    logic scl_drive_low;

    integer error_count;

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

        .sda_in        (sda_in),
        .scl_in        (scl_in),

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

        clk         = 1'b0;
        rst_n       = 1'b0;

        cmd_valid   = 1'b0;
        cmd_rw      = 1'b0;
        cmd_addr    = 7'h50;
        cmd_wdata   = 8'hA5;

        /*
         * Begin with electrically free bus.
         */
        sda_in      = 1'b1;
        scl_in      = 1'b1;

        error_count = 0;

        /*
         * ------------------------------------------------------------
         * TEST 1: RESET
         * ------------------------------------------------------------
         */

        repeat (4) @(posedge clk);

        check(
            "RESET_SDA_RELEASED",
            sda_drive_low == 1'b0
        );

        check(
            "RESET_SCL_RELEASED",
            scl_drive_low == 1'b0
        );

        check(
            "RESET_NOT_BUSY",
            busy == 1'b0
        );

        check(
            "RESET_NOT_READY_BEFORE_TBUF",
            cmd_ready == 1'b0
        );

        rst_n = 1'b1;

        /*
         * ------------------------------------------------------------
         * TEST 2: BUS FREE FOR LESS THAN tBUF
         * ------------------------------------------------------------
         */

        repeat (200) @(posedge clk);

        check(
            "NOT_READY_BEFORE_TBUF",
            cmd_ready == 1'b0
        );

        /*
         * Disturb the free-bus qualification.
         *
         * Drive the external input on the falling edge so the DUT
         * observes a stable value at the following rising edge.
         */
        @(negedge clk);
        sda_in = 1'b0;

        @(posedge clk);
        #1;

        check(
            "BUS_FREE_COUNTER_RESETS_ON_SDA_LOW",
            cmd_ready == 1'b0
        );

        /*
         * Release SDA between DUT sampling edges.
         */
        @(negedge clk);
        sda_in = 1'b1;

        /*
         * ------------------------------------------------------------
         * TEST 3: COUNTER RESTART
         * ------------------------------------------------------------
         */

        repeat (T_BUF_CYCLES - 1) @(posedge clk);
        #1;

        check(
            "NOT_READY_AT_TBUF_MINUS_1_AFTER_RESTART",
            cmd_ready == 1'b0
        );

        /*
         * Qualifying sample 470.
         */
        @(posedge clk);
        #1;

        check(
            "READY_AT_TBUF",
            cmd_ready == 1'b1
        );

        check(
            "IDLE_SDA_RELEASED",
            sda_drive_low == 1'b0
        );

        check(
            "IDLE_SCL_RELEASED",
            scl_drive_low == 1'b0
        );

        check(
            "IDLE_NOT_BUSY",
            busy == 1'b0
        );

        /*
         * ------------------------------------------------------------
         * TEST 4: LOSS OF BUS-FREE CONDITION
         * ------------------------------------------------------------
         */

        scl_in = 1'b0;

        @(posedge clk);
        #1;

        check(
            "READY_CLEARS_WHEN_BUS_NOT_FREE",
            cmd_ready == 1'b0
        );

        scl_in = 1'b1;

        /*
         * ------------------------------------------------------------
         * FINAL RESULT
         * ------------------------------------------------------------
         */

        if (error_count == 0) begin

            $display("");
            $display("==========================================");
            $display("S5.2A IDLE/BUS-FREE REGRESSION : PASS");
            $display("ERROR COUNT = %0d", error_count);
            $display("==========================================");

        end
        else begin

            $fatal(
                1,
                "S5.2A IDLE/BUS-FREE REGRESSION FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule