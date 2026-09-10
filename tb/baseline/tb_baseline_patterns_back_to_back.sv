`timescale 1ns/1ps

module tb_baseline_patterns_back_to_back;

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
    logic [7:0] patterns [0:7];

    integer error_count;
    integer bit_number;
    integer pattern_index;
    integer write_count;
    integer read_count;
    integer transaction_count;

    /*
     * Open-drain bus model.
     *
     * Any participant may pull LOW.
     * Nobody actively drives HIGH.
     */
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


    /*
     * ================================================================
     * COMMAND GENERATION
     * ================================================================
     */

    task automatic issue_write(
        input logic [7:0] data
    );
        begin

            /*
             * No artificial inter-transaction delay is inserted.
             * Launch as soon as post-STOP tBUF restores cmd_ready.
             */
            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw    = 1'b0;
            cmd_wdata = data;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                "PATTERN_WRITE_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            @(negedge clk);
            cmd_valid = 1'b0;

        end
    endtask


    task automatic issue_read;
        begin

            /*
             * Again, launch at the first legal opportunity after tBUF.
             */
            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw    = 1'b1;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                "PATTERN_READ_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            @(negedge clk);
            cmd_valid = 1'b0;

        end
    endtask


    /*
     * ================================================================
     * COMMON BUS CAPTURE / ACK
     * ================================================================
     */

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
     * Call immediately after capture_bus_byte().
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
     * ================================================================
     * READ TARGET DATA
     * ================================================================
     */

    task automatic target_send_byte(
        input logic [7:0] data
    );
        begin

            /*
             * Begins while SCL is LOW immediately after the address ACK.
             */
            for (
                bit_number = 7;
                bit_number >= 0;
                bit_number = bit_number - 1
            ) begin

                /*
                 * Open drain:
                 *
                 * data 0 -> target drives LOW
                 * data 1 -> target releases SDA
                 */
                target_sda_hold_low = ~data[bit_number];

                #1;

                check(
                    "MASTER_RELEASES_SDA_DURING_PATTERN_READ",
                    sda_drive_low == 1'b0
                );

                @(posedge scl_bus);
                #1;

                check(
                    "PATTERN_READ_BUS_BIT_MATCHES_TARGET",
                    sda_bus == data[bit_number]
                );

                @(negedge scl_bus);
                #1;

            end

            /*
             * Release SDA after the eighth data bit.
             */
            target_sda_hold_low = 1'b0;

        end
    endtask


    /*
     * ================================================================
     * WRITE COMPLETION
     * ================================================================
     */

    task automatic check_write_stop_done;
        begin

            /*
             * Called immediately after the falling edge following the
             * data ACK clock.
             *
             * ST_STOP applies its preparation outputs on the following
             * system-clock rising edge.
             */
            @(posedge clk);
            #1;

            check(
                "WRITE_STOP_PREP_SDA_LOW",
                sda_bus == 1'b0
            );

            check(
                "WRITE_STOP_PREP_SCL_LOW",
                scl_bus == 1'b0
            );

            /*
             * SCL rises while SDA remains LOW.
             */
            @(posedge scl_bus);
            #1;

            check(
                "WRITE_STOP_SETUP_SDA_LOW",
                sda_bus == 1'b0
            );

            /*
             * STOP: SDA rises while SCL is HIGH.
             */
            @(posedge sda_bus);
            #1;

            check(
                "WRITE_STOP_WHILE_SCL_HIGH",
                scl_bus == 1'b1
            );

            /*
             * ST_DONE executes on the following system-clock edge.
             */
            @(posedge clk);
            #1;

            check(
                "WRITE_DONE_ASSERTED",
                done == 1'b1
            );

            check(
                "WRITE_BUSY_CLEARED",
                busy == 1'b0
            );

            check(
                "WRITE_NACK_STATUS_CLEAR",
                nack == 1'b0
            );

            check(
                "WRITE_LINES_RELEASED_AFTER_STOP",
                (sda_drive_low == 1'b0) &&
                (scl_drive_low == 1'b0)
            );

            /*
             * done is exactly one system-clock pulse.
             */
            @(posedge clk);
            #1;

            check(
                "WRITE_DONE_ONE_CLOCK_PULSE",
                done == 1'b0
            );

            check(
                "WRITE_NOT_READY_BEFORE_POST_STOP_TBUF",
                cmd_ready == 1'b0
            );

            /*
             * The next transaction starts immediately after this
             * qualification completes.
             */
            wait (cmd_ready === 1'b1);

            check(
                "WRITE_READY_AFTER_POST_STOP_TBUF",
                cmd_ready == 1'b1
            );

        end
    endtask


    /*
     * ================================================================
     * READ COMPLETION
     * ================================================================
     */

    task automatic check_read_nack_stop_done(
        input logic [7:0] expected_data
    );
        begin

            /*
             * Immediately after the eighth data-clock falling edge,
             * the complete received byte must already be available.
             */
            check(
                "PATTERN_READ_DATA_CAPTURED",
                read_data == expected_data
            );

            check(
                "MASTER_SDA_RELEASED_BEFORE_FINAL_NACK",
                sda_drive_low == 1'b0
            );

            /*
             * Ninth clock: master terminates the one-byte READ by
             * NACKing, implemented by leaving SDA released/HIGH.
             */
            @(posedge scl_bus);
            #1;

            check(
                "MASTER_FINAL_NACK_LEVEL_HIGH",
                sda_bus == 1'b1
            );

            check(
                "MASTER_DOES_NOT_DRIVE_SDA_FOR_NACK",
                sda_drive_low == 1'b0
            );

            /*
             * End of the ninth clock.
             */
            @(negedge scl_bus);
            #1;

            /*
             * ST_STOP applies preparation outputs on the following
             * system-clock rising edge.
             */
            @(posedge clk);
            #1;

            check(
                "READ_STOP_PREP_SDA_LOW",
                sda_bus == 1'b0
            );

            check(
                "READ_STOP_PREP_SCL_LOW",
                scl_bus == 1'b0
            );

            @(posedge scl_bus);
            #1;

            check(
                "READ_STOP_SETUP_SDA_LOW",
                sda_bus == 1'b0
            );

            @(posedge sda_bus);
            #1;

            check(
                "READ_STOP_WHILE_SCL_HIGH",
                scl_bus == 1'b1
            );

            @(posedge clk);
            #1;

            check(
                "READ_DONE_ASSERTED",
                done == 1'b1
            );

            check(
                "READ_BUSY_CLEARED",
                busy == 1'b0
            );

            /*
             * The master's final NACK is normal read termination.
             * It must not set the target-NACK error status.
             */
            check(
                "READ_NACK_STATUS_CLEAR",
                nack == 1'b0
            );

            check(
                "PATTERN_READ_DATA_RETAINED_AFTER_DONE",
                read_data == expected_data
            );

            check(
                "READ_LINES_RELEASED_AFTER_STOP",
                (sda_drive_low == 1'b0) &&
                (scl_drive_low == 1'b0)
            );

            @(posedge clk);
            #1;

            check(
                "READ_DONE_ONE_CLOCK_PULSE",
                done == 1'b0
            );

            check(
                "READ_NOT_READY_BEFORE_POST_STOP_TBUF",
                cmd_ready == 1'b0
            );

            wait (cmd_ready === 1'b1);

            check(
                "READ_READY_AFTER_POST_STOP_TBUF",
                cmd_ready == 1'b1
            );

        end
    endtask


    /*
     * ================================================================
     * COMPLETE SUCCESSFUL WRITE
     * ================================================================
     */

    task automatic run_write_pattern(
        input logic [7:0] data
    );
        begin

            $display(
                "[INFO] BEGIN WRITE PATTERN DATA=0x%02h",
                data
            );

            issue_write(data);

            /*
             * Address byte = {7'h50, WRITE} = A0.
             */
            capture_bus_byte();

            check(
                "PATTERN_WRITE_ADDRESS_A0",
                captured_byte == 8'hA0
            );

            target_ack();

            /*
             * Payload.
             */
            capture_bus_byte();

            check(
                "PATTERN_WRITE_DATA_MATCH",
                captured_byte == data
            );

            target_ack();

            check_write_stop_done();

            write_count       = write_count + 1;
            transaction_count = transaction_count + 1;

            $display(
                "[INFO] END WRITE PATTERN DATA=0x%02h",
                data
            );

        end
    endtask


    /*
     * ================================================================
     * COMPLETE SUCCESSFUL READ
     * ================================================================
     */

    task automatic run_read_pattern(
        input logic [7:0] data
    );
        begin

            $display(
                "[INFO] BEGIN READ PATTERN DATA=0x%02h",
                data
            );

            issue_read();

            /*
             * Address byte = {7'h50, READ} = A1.
             */
            capture_bus_byte();

            check(
                "PATTERN_READ_ADDRESS_A1",
                captured_byte == 8'hA1
            );

            target_ack();

            /*
             * Target supplies the requested test byte.
             */
            target_send_byte(data);

            check_read_nack_stop_done(data);

            read_count        = read_count + 1;
            transaction_count = transaction_count + 1;

            $display(
                "[INFO] END READ PATTERN DATA=0x%02h",
                data
            );

        end
    endtask


    /*
     * ================================================================
     * WATCHDOG
     * ================================================================
     */

    initial begin

        #10_000_000;

        $fatal(
            1,
            "S5.6 PATTERN/BACK-TO-BACK WATCHDOG"
        );

    end


    /*
     * ================================================================
     * MAIN TEST
     * ================================================================
     */

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
        write_count         = 0;
        read_count          = 0;
        transaction_count   = 0;

        /*
         * Frozen baseline data-pattern set.
         */
        patterns[0] = 8'h00;
        patterns[1] = 8'hFF;
        patterns[2] = 8'hAA;
        patterns[3] = 8'h55;
        patterns[4] = 8'h01;
        patterns[5] = 8'h80;
        patterns[6] = 8'h3C;
        patterns[7] = 8'hA5;

        /*
         * Reset.
         */
        repeat (4) @(posedge clk);

        @(negedge clk);
        rst_n = 1'b1;

        wait (cmd_ready === 1'b1);

        check(
            "PATTERN_TEST_INITIAL_READY",
            cmd_ready == 1'b1
        );

        check(
            "INITIAL_OPEN_DRAIN_LINES_RELEASED",
            (sda_drive_low == 1'b0) &&
            (scl_drive_low == 1'b0) &&
            (sda_bus == 1'b1) &&
            (scl_bus == 1'b1)
        );

        /*
         * ============================================================
         * FROZEN PATTERN / BACK-TO-BACK SEQUENCE
         *
         * For every pattern:
         *
         *     successful WRITE
         *          immediately after legal tBUF
         *     successful READ
         *          immediately after legal tBUF
         *
         * Then move directly to the next pattern.
         *
         * Total = 8 writes + 8 reads = 16 transactions.
         * ============================================================
         */

        for (
            pattern_index = 0;
            pattern_index < 8;
            pattern_index = pattern_index + 1
        ) begin

            $display("");
            $display(
                "===== PATTERN %0d : 0x%02h =====",
                pattern_index,
                patterns[pattern_index]
            );

            run_write_pattern(
                patterns[pattern_index]
            );

            run_read_pattern(
                patterns[pattern_index]
            );

        end

        /*
         * ============================================================
         * FINAL COVERAGE CHECKS
         * ============================================================
         */

        check(
            "ALL_EIGHT_WRITE_PATTERNS_COMPLETED",
            write_count == 8
        );

        check(
            "ALL_EIGHT_READ_PATTERNS_COMPLETED",
            read_count == 8
        );

        check(
            "SIXTEEN_BACK_TO_BACK_TRANSACTIONS_COMPLETED",
            transaction_count == 16
        );

        check(
            "FINAL_BUS_READY",
            cmd_ready == 1'b1
        );

        check(
            "FINAL_OPEN_DRAIN_LINES_RELEASED",
            (sda_drive_low == 1'b0) &&
            (scl_drive_low == 1'b0) &&
            (sda_bus == 1'b1) &&
            (scl_bus == 1'b1)
        );

        /*
         * ============================================================
         * FINAL RESULT
         * ============================================================
         */

        if (error_count == 0) begin

            $display("");
            $display("============================================");
            $display("S5.6 PATTERN/BACK-TO-BACK TEST : PASS");
            $display("WRITE PATTERNS COMPLETED = %0d", write_count);
            $display("READ PATTERNS COMPLETED  = %0d", read_count);
            $display("TRANSACTION COUNT        = %0d", transaction_count);
            $display("ERROR COUNT = %0d", error_count);
            $display("============================================");

        end
        else begin

            $fatal(
                1,
                "S5.6 PATTERN/BACK-TO-BACK TEST FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule