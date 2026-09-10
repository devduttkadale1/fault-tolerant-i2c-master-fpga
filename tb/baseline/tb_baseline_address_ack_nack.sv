`timescale 1ns/1ps

module tb_baseline_address_ack_nack;

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

    time stop_scl_high_time;
    time stop_time;

    /*
     * Open-drain bus model.
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

    task automatic issue_command(
        input logic rw
    );
        begin

            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw    = rw;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                "COMMAND_ACCEPTED_BUSY",
                busy == 1'b1
            );

            @(negedge clk);

            cmd_valid = 1'b0;

        end
    endtask

    task automatic capture_address_byte;
        begin

            captured_address = 8'h00;

            for (bit_number = 7;
                 bit_number >= 0;
                 bit_number = bit_number - 1) begin

                @(posedge scl_bus);
                #1;

                captured_address[bit_number] = sda_bus;

            end

        end
    endtask

    /*
     * Simulation watchdog.
     */
    initial begin

        #1_000_000;

        $fatal(
            1,
            "S5.3 WATCHDOG: simulation did not finish"
        );

    end

    initial begin

        clk                 = 1'b0;
        rst_n               = 1'b0;

        cmd_valid           = 1'b0;
        cmd_rw              = 1'b0;
        cmd_addr            = 7'h50;
        cmd_wdata           = 8'hA5;

        target_sda_hold_low = 1'b0;
        target_scl_hold_low = 1'b0;

        captured_address    = 8'h00;

        error_count         = 0;

        /*
         * ============================================================
         * RESET / INITIAL BUS FREE
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
         * TEST 1
         *
         * WRITE ADDRESS + TARGET NACK
         *
         * Address:
         *
         *   7'h50 + WRITE = 8'hA0
         * ============================================================
         */

        issue_command(1'b0);

        capture_address_byte();

        check(
            "WRITE_ADDRESS_BYTE_IS_A0",
            captured_address == 8'hA0
        );

        /*
         * End of eighth address-bit HIGH phase.
         */
        @(negedge scl_bus);
        #1;

        check(
            "MASTER_RELEASES_SDA_FOR_ACK",
            sda_drive_low == 1'b0
        );

        /*
         * Target deliberately does NOT drive SDA LOW.
         *
         * Therefore ninth clock must be interpreted as NACK.
         */
        target_sda_hold_low = 1'b0;

        @(posedge scl_bus);
        #1;

        check(
            "NACK_LEVEL_HIGH_ON_NINTH_CLOCK",
            sda_bus == 1'b1
        );

        /*
         * Wait until ninth-clock HIGH interval completes.
         */
        @(negedge scl_bus);
        #1;

        check(
            "NACK_CAPTURED",
            nack == 1'b1
        );

        check(
            "BUSY_DURING_NACK_STOP_SEQUENCE",
            busy == 1'b1
        );

                /*
         * STOP preparation:
         *
         * The ninth-clock falling edge transitions the FSM into
         * ST_STOP. The ST_STOP outputs are applied on the following
         * rising system-clock edge.
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
         * Controller then releases SCL while SDA remains LOW.
         */
        @(posedge scl_bus);

        stop_scl_high_time = $time;

        #1;

        check(
            "STOP_SETUP_SDA_STILL_LOW",
            sda_bus == 1'b0
        );

        /*
         * STOP itself is SDA LOW -> HIGH while SCL is HIGH.
         */
        @(posedge sda_bus);

        stop_time = $time;

        #1;

        check(
            "STOP_GENERATED_WHILE_SCL_HIGH",
            scl_bus == 1'b1
        );

        check(
            "STOP_SETUP_AT_LEAST_5US",
            (stop_time - stop_scl_high_time) >= 5000
        );

        /*
         * ST_DONE executes at the next system-clock edge.
         */
        @(posedge clk);
        #1;

        check(
            "DONE_ASSERTED_AFTER_NACK_STOP",
            done == 1'b1
        );

        check(
            "NOT_BUSY_AFTER_NACK_STOP",
            busy == 1'b0
        );

        check(
            "NACK_STATUS_RETAINED",
            nack == 1'b1
        );

        check(
            "SDA_RELEASED_AFTER_STOP",
            sda_drive_low == 1'b0
        );

        check(
            "SCL_RELEASED_AFTER_STOP",
            scl_drive_low == 1'b0
        );

        /*
         * done must be one system-clock pulse.
         */
        @(posedge clk);
        #1;

        check(
            "DONE_IS_ONE_CLOCK_PULSE",
            done == 1'b0
        );

        check(
            "NOT_READY_IMMEDIATELY_AFTER_STOP",
            cmd_ready == 1'b0
        );

        /*
         * Bus must pass tBUF qualification again.
         */
        wait (cmd_ready === 1'b1);

        check(
            "READY_RETURNS_AFTER_POST_STOP_TBUF",
            cmd_ready == 1'b1
        );

        /*
         * ============================================================
         * TEST 2
         *
         * READ ADDRESS + TARGET ACK
         *
         * Address:
         *
         *   7'h50 + READ = 8'hA1
         *
         * S5.5 will later implement the actual read byte.
         * For now we prove address ACK recognition and safe transition
         * into the READ-data placeholder.
         * ============================================================
         */

        issue_command(1'b1);

        capture_address_byte();

        check(
            "READ_ADDRESS_BYTE_IS_A1",
            captured_address == 8'hA1
        );

        /*
         * End of eighth bit.
         */
        @(negedge scl_bus);
        #1;

        check(
            "MASTER_RELEASES_SDA_FOR_READ_ACK",
            sda_drive_low == 1'b0
        );

        /*
         * Target acknowledges by pulling SDA LOW during ninth clock.
         */
        target_sda_hold_low = 1'b1;

        @(posedge scl_bus);
        #1;

        check(
            "ACK_LEVEL_LOW_ON_NINTH_CLOCK",
            sda_bus == 1'b0
        );

        /*
         * Keep ACK asserted through the sampling point and until the
         * ninth HIGH interval completes.
         */
        @(negedge scl_bus);
        #1;

        check(
            "ACK_RECOGNIZED_NOT_NACK",
            nack == 1'b0
        );

        /*
         * SCL is now LOW and the core has entered the safe READ-data
         * placeholder.
         */
        @(negedge clk);

        target_sda_hold_low = 1'b0;

        @(posedge clk);
        #1;

        check(
            "READ_ACK_TRANSACTION_REMAINS_ACTIVE",
            busy == 1'b1
        );

        check(
            "NO_DONE_ON_SUCCESSFUL_ADDRESS_ACK",
            done == 1'b0
        );

        check(
            "READ_PATH_BEGINS_WITH_SCL_LOW",
            scl_drive_low == 1'b1
        );

        /*
         * ============================================================
         * FINAL RESULT
         * ============================================================
         */

        if (error_count == 0) begin

            $display("");
            $display("===========================================");
            $display("S5.3 ADDRESS ACK/NACK TEST : PASS");
            $display("ERROR COUNT = %0d", error_count);
            $display("===========================================");

        end
        else begin

            $fatal(
                1,
                "S5.3 ADDRESS ACK/NACK TEST FAILED: %0d errors",
                error_count
            );

        end

        $finish;

    end

endmodule