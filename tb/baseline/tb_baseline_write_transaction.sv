`timescale 1ns/1ps

module tb_baseline_write_transaction;

    localparam integer SYS_CLK_HZ = 100_000_000;
    localparam integer I2C_CLK_HZ = 100_000;

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

    logic target_sda_hold_low;
    logic target_scl_hold_low;

    wire sda_bus;
    wire scl_bus;

    logic [7:0] captured_byte;

    integer error_count;
    integer bit_number;

    assign sda_bus =
        (sda_drive_low || target_sda_hold_low) ?
        1'b0 :
        1'b1;

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

    task automatic issue_write(
        input logic [7:0] data
    );
        begin

            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw    = 1'b0;
            cmd_wdata = data;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                "WRITE_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            @(negedge clk);
            cmd_valid = 1'b0;

        end
    endtask

    task automatic capture_bus_byte;
        begin

            captured_byte = 8'h00;

            for (
                bit_number = 7;
                bit_number >= 0;
                bit_number = bit_number - 1
            ) begin

                @(posedge scl_bus);
                #1;

                captured_byte[bit_number] = sda_bus;

            end

        end
    endtask

    /*
     * Target ACKs the next ninth clock.
     *
     * Call this immediately after capture_bus_byte().
     */
    task automatic target_ack;
        begin

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b1;

            @(posedge scl_bus);
            #1;

            check(
                "TARGET_ACK_LEVEL_LOW",
                sda_bus == 1'b0
            );

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b0;

        end
    endtask

    /*
     * Target NACKs by leaving SDA released.
     */
    task automatic target_nack;
        begin

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b0;

            @(posedge scl_bus);
            #1;

            check(
                "TARGET_NACK_LEVEL_HIGH",
                sda_bus == 1'b1
            );

            @(negedge scl_bus);
            #1;

        end
    endtask

    task automatic check_stop_and_done(
        input logic expected_nack
    );
        begin

            /*
             * We are at the falling edge immediately following the
             * ninth ACK/NACK HIGH interval.
             *
             * ST_STOP applies its preparation outputs on the following
             * system-clock rising edge.
             */
            @(posedge clk);
            #1;

            check(
                "STOP_PREP_SDA_LOW",
                sda_bus == 1'b0
            );

            check(
                "STOP_PREP_SCL_LOW",
                scl_bus == 1'b0
            );

            /*
             * SCL rises while SDA stays LOW.
             */
            @(posedge scl_bus);
            #1;

            check(
                "STOP_SETUP_SDA_LOW",
                sda_bus == 1'b0
            );

            /*
             * SDA then rises while SCL remains HIGH.
             */
            @(posedge sda_bus);
            #1;

            check(
                "STOP_WHILE_SCL_HIGH",
                scl_bus == 1'b1
            );

            /*
             * ST_DONE executes on the following system-clock edge.
             */
            @(posedge clk);
            #1;

            check(
                "DONE_ASSERTED",
                done == 1'b1
            );

            check(
                "BUSY_CLEARED",
                busy == 1'b0
            );

            check(
                "NACK_STATUS_EXPECTED",
                nack == expected_nack
            );

            check(
                "LINES_RELEASED_AFTER_STOP",
                (sda_drive_low == 1'b0) &&
                (scl_drive_low == 1'b0)
            );

            @(posedge clk);
            #1;

            check(
                "DONE_ONE_CLOCK_PULSE",
                done == 1'b0
            );

        end
    endtask

    /*
     * Watchdog.
     */
    initial begin

        #2_000_000;

        $fatal(
            1,
            "S5.4 WATCHDOG: simulation did not finish"
        );

    end

    initial begin

        clk                 = 1'b0;
        rst_n               = 1'b0;

        cmd_valid           = 1'b0;
        cmd_rw              = 1'b0;
        cmd_addr            = 7'h50;
        cmd_wdata           = 8'h00;

        target_sda_hold_low = 1'b0;
        target_scl_hold_low = 1'b0;

        captured_byte       = 8'h00;
        error_count         = 0;

        /*
         * ============================================================
         * RESET
         * ============================================================
         */

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (cmd_ready === 1'b1);

        check(
            "INITIAL_BUS_READY",
            cmd_ready == 1'b1
        );

        /*
         * ============================================================
         * TEST 1: SUCCESSFUL WRITE
         *
         * Address 0x50 -> write address byte 0xA0
         * Data         -> 0xA5
         * ============================================================
         */

        issue_write(8'hA5);

        capture_bus_byte();

        check(
            "WRITE1_ADDRESS_BYTE_A0",
            captured_byte == 8'hA0
        );

        target_ack();

        check(
            "WRITE1_ADDRESS_ACK_RECOGNIZED",
            nack == 1'b0
        );

        /*
         * Next eight SCL rising edges are the payload.
         */
        capture_bus_byte();

        check(
            "WRITE1_DATA_BYTE_A5",
            captured_byte == 8'hA5
        );

        target_ack();

        check(
            "WRITE1_DATA_ACK_RECOGNIZED",
            nack == 1'b0
        );

        check_stop_and_done(1'b0);

        check(
            "NOT_READY_IMMEDIATELY_AFTER_WRITE1",
            cmd_ready == 1'b0
        );

        wait (cmd_ready === 1'b1);

        check(
            "READY_AFTER_WRITE1_TBUF",
            cmd_ready == 1'b1
        );

        /*
         * ============================================================
         * TEST 2: DATA NACK
         *
         * Address is ACKed.
         * Payload 0x3C is transmitted.
         * Target NACKs the data byte.
         * ============================================================
         */

        issue_write(8'h3C);

        capture_bus_byte();

        check(
            "WRITE2_ADDRESS_BYTE_A0",
            captured_byte == 8'hA0
        );

        target_ack();

        check(
            "WRITE2_ADDRESS_ACK_RECOGNIZED",
            nack == 1'b0
        );

        capture_bus_byte();

        check(
            "WRITE2_DATA_BYTE_3C",
            captured_byte == 8'h3C
        );

        target_nack();

        check(
            "WRITE2_DATA_NACK_CAPTURED",
            nack == 1'b1
        );

        check_stop_and_done(1'b1);

        wait (cmd_ready === 1'b1);

        check(
            "READY_AFTER_WRITE2_TBUF",
            cmd_ready == 1'b1
        );

        /*
         * ============================================================
         * FINAL
         * ============================================================
         */

        if (error_count == 0) begin

            $display("");
            $display("===========================================");
            $display("S5.4 WRITE TRANSACTION TEST : PASS");
            $display("ERROR COUNT = %0d", error_count);
            $display("===========================================");

        end
        else begin

            $fatal(
                1,
                "S5.4 WRITE TRANSACTION TEST FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule