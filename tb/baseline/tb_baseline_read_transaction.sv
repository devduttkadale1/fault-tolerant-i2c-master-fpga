`timescale 1ns/1ps

module tb_baseline_read_transaction;

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

    logic [7:0] captured_address;

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

    task automatic issue_read;
        begin

            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw    = 1'b1;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                "READ_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            @(negedge clk);
            cmd_valid = 1'b0;

        end
    endtask

    task automatic capture_address_byte;
        begin

            captured_address = 8'h00;

            for (
                bit_number = 7;
                bit_number >= 0;
                bit_number = bit_number - 1
            ) begin

                @(posedge scl_bus);
                #1;

                captured_address[bit_number] = sda_bus;

            end

        end
    endtask

    /*
     * ACK the address.
     *
     * Returns immediately after the ninth-clock falling edge.
     */
    task automatic target_address_ack;
        begin

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b1;

            @(posedge scl_bus);
            #1;

            check(
                "TARGET_ADDRESS_ACK_LOW",
                sda_bus == 1'b0
            );

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b0;

        end
    endtask

    /*
     * Drive one byte MSB first.
     *
     * The task begins while SCL is LOW immediately after the address
     * ACK clock.
     */
    task automatic target_send_byte(
        input logic [7:0] data
    );
        begin

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
                    "MASTER_RELEASES_SDA_DURING_READ",
                    sda_drive_low == 1'b0
                );

                @(posedge scl_bus);
                #1;

                check(
                    "READ_BUS_BIT_MATCHES_TARGET",
                    sda_bus == data[bit_number]
                );

                @(negedge scl_bus);
                #1;

            end

            /*
             * Target releases SDA after the eighth data bit.
             */
            target_sda_hold_low = 1'b0;

        end
    endtask

    task automatic check_master_nack_stop_done(
        input logic [7:0] expected_data
    );
        begin

            /*
             * We are immediately after the eighth data-clock falling
             * edge. The core should now contain the complete byte.
             */
            check(
                "READ_DATA_CAPTURED",
                read_data == expected_data
            );

            check(
                "MASTER_SDA_RELEASED_BEFORE_FINAL_NACK",
                sda_drive_low == 1'b0
            );

            /*
             * Ninth clock: master must NACK by leaving SDA HIGH.
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
             * End of ninth clock.
             */
            @(negedge scl_bus);
            #1;

            /*
             * ST_STOP applies its preparation outputs on the next
             * rising system-clock edge.
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
             * A successful READ address ACK does not represent a target
             * NACK error. The master's final read NACK is protocol
             * termination, not an error condition.
             */
            check(
                "READ_NACK_STATUS_CLEAR",
                nack == 1'b0
            );

            check(
                "READ_DATA_RETAINED_AFTER_DONE",
                read_data == expected_data
            );

            @(posedge clk);
            #1;

            check(
                "READ_DONE_ONE_CLOCK_PULSE",
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
            "S5.5 WATCHDOG: simulation did not finish"
        );

    end

    initial begin

        clk                 = 1'b0;
        rst_n               = 1'b0;

        cmd_valid           = 1'b0;
        cmd_rw              = 1'b1;
        cmd_addr            = 7'h50;
        cmd_wdata           = 8'h00;

        target_sda_hold_low = 1'b0;
        target_scl_hold_low = 1'b0;

        captured_address    = 8'h00;
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
         * READ TEST 1: 0x5A
         * ============================================================
         */

        issue_read();

        capture_address_byte();

        check(
            "READ1_ADDRESS_BYTE_A1",
            captured_address == 8'hA1
        );

        target_address_ack();

        check(
            "READ1_ADDRESS_ACK_RECOGNIZED",
            nack == 1'b0
        );

        target_send_byte(8'h5A);

        check_master_nack_stop_done(8'h5A);

        check(
            "NOT_READY_IMMEDIATELY_AFTER_READ1",
            cmd_ready == 1'b0
        );

        wait (cmd_ready === 1'b1);

        check(
            "READY_AFTER_READ1_TBUF",
            cmd_ready == 1'b1
        );

        /*
         * ============================================================
         * READ TEST 2: 0xC3
         *
         * Second pattern ensures the receive shift/index logic is not
         * accidentally specialized to a single value.
         * ============================================================
         */

        issue_read();

        capture_address_byte();

        check(
            "READ2_ADDRESS_BYTE_A1",
            captured_address == 8'hA1
        );

        target_address_ack();

        target_send_byte(8'hC3);

        check_master_nack_stop_done(8'hC3);

        wait (cmd_ready === 1'b1);

        check(
            "READY_AFTER_READ2_TBUF",
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
            $display("S5.5 READ TRANSACTION TEST : PASS");
            $display("ERROR COUNT = %0d", error_count);
            $display("===========================================");

        end
        else begin

            $fatal(
                1,
                "S5.5 READ TRANSACTION TEST FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule