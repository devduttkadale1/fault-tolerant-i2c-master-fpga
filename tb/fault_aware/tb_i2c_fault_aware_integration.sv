`timescale 1ns/1ps

module tb_i2c_fault_aware_integration;

    /*
     * ================================================================
     * Accelerated integration-test configuration
     * ================================================================
     *
     * Production:
     *
     *     SYS_CLK_HZ = 100 MHz
     *     I2C_CLK_HZ = 100 kHz
     *
     * Integration regression:
     *
     *     SYS_CLK_HZ = 10 MHz
     *     I2C_CLK_HZ = 1 MHz
     *
     * The cycle relationships remain identical while fault detection,
     * recovery and normal protocol transactions complete faster.
     */
    localparam integer SYS_CLK_HZ = 10_000_000;
    localparam integer I2C_CLK_HZ = 1_000_000;

    localparam integer F1_LIMIT = 3;
    localparam integer F2_LIMIT = 5;

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

    logic       fault_active;
    logic [1:0] fault_code;
    logic       recovery_active;
    logic       recovery_failed;


    /*
     * ================================================================
     * Open-drain target and deliberate fault injection
     * ================================================================
     */
    logic target_sda_hold_low;
    logic target_scl_hold_low;

    logic fault_sda_hold_low;
    logic fault_scl_hold_low;

    wire sda_bus;
    wire scl_bus;


    /*
     * Any participant may pull LOW.
     *
     * No participant ever actively drives HIGH.
     */
    assign sda_bus =
        (
            sda_drive_low ||
            target_sda_hold_low ||
            fault_sda_hold_low
        ) ?
        1'b0 :
        1'b1;


    assign scl_bus =
        (
            scl_drive_low ||
            target_scl_hold_low ||
            fault_scl_hold_low
        ) ?
        1'b0 :
        1'b1;


    /*
     * ================================================================
     * Verification bookkeeping
     * ================================================================
     */
    logic [7:0] captured_byte;

    integer error_count;
    integer bit_number;

    integer done_event_count;
    integer abort_event_count;
    integer recovery_scl_low_edge_count;

    integer guard;


    /*
     * ================================================================
     * DUT
     * ================================================================
     */
    i2c_master_fault_aware #(
        .SYS_CLK_HZ              (SYS_CLK_HZ),
        .I2C_CLK_HZ              (I2C_CLK_HZ),
        .SDA_STUCK_LIMIT_CYCLES  (F1_LIMIT),
        .SCL_STALL_LIMIT_CYCLES  (F2_LIMIT)
    ) dut (
        .clk                     (clk),
        .rst_n                   (rst_n),

        .cmd_valid               (cmd_valid),
        .cmd_ready               (cmd_ready),

        .cmd_rw                  (cmd_rw),
        .cmd_addr                (cmd_addr),
        .cmd_wdata               (cmd_wdata),

        .read_data               (read_data),
        .busy                    (busy),
        .done                    (done),
        .nack                    (nack),

        .sda_in                  (sda_bus),
        .scl_in                  (scl_bus),

        .sda_drive_low           (sda_drive_low),
        .scl_drive_low           (scl_drive_low),

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
     * Event monitors
     * ================================================================
     */
    always @(posedge done) begin

        if (rst_n) begin

            done_event_count =
                done_event_count + 1;

        end

    end


    always @(posedge dut.manager_fault_abort) begin

        if (rst_n) begin

            abort_event_count =
                abort_event_count + 1;

        end

    end


    /*
     * Count physical recovery LOW pulses only while the recovery manager
     * owns the wrapper output mux.
     */
    always @(posedge scl_drive_low) begin

        if (
            rst_n &&
            dut.manager_recovery_owns_bus
        ) begin

            recovery_scl_low_edge_count =
                recovery_scl_low_edge_count + 1;

        end

    end


    /*
     * ================================================================
     * Reset
     * ================================================================
     */
    task automatic reset_dut;
        begin

            cmd_valid = 1'b0;
            cmd_rw    = 1'b0;
            cmd_addr  = 7'h50;
            cmd_wdata = 8'h00;

            target_sda_hold_low = 1'b0;
            target_scl_hold_low = 1'b0;

            fault_sda_hold_low = 1'b0;
            fault_scl_hold_low = 1'b0;

            rst_n = 1'b0;

            repeat (4) begin
                @(posedge clk);
            end

            @(negedge clk);

            rst_n = 1'b1;

            /*
             * Clear unit-test counters after reset release.
             */
            done_event_count = 0;
            abort_event_count = 0;
            recovery_scl_low_edge_count = 0;

            guard = 0;

            while (cmd_ready !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 500) begin

                    $fatal(
                        1,
                        "Timed out waiting for initial cmd_ready"
                    );

                end

            end


            check(
                "RESET_CMD_READY_AFTER_TBUF",
                cmd_ready == 1'b1
            );

            check(
                "RESET_BUSY_CLEAR",
                busy == 1'b0
            );

            check(
                "RESET_DONE_CLEAR",
                done == 1'b0
            );

            check(
                "RESET_NACK_CLEAR",
                nack == 1'b0
            );

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
                "RESET_SDA_RELEASED",
                sda_drive_low == 1'b0
            );

            check(
                "RESET_SCL_RELEASED",
                scl_drive_low == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * Command generation
     * ================================================================
     */
    task automatic issue_write(
        input logic [7:0] data
    );
        begin

            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw     = 1'b0;
            cmd_addr   = 7'h50;
            cmd_wdata  = data;
            cmd_valid  = 1'b1;

            @(posedge clk);
            #1;

            check(
                "WRITE_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            check(
                "WRITE_ACCEPT_REMOVES_READY",
                cmd_ready == 1'b0
            );

            @(negedge clk);

            cmd_valid = 1'b0;

        end

    endtask


    task automatic issue_read;
        begin

            wait (cmd_ready === 1'b1);

            @(negedge clk);

            cmd_rw     = 1'b1;
            cmd_addr   = 7'h50;
            cmd_valid  = 1'b1;

            @(posedge clk);
            #1;

            check(
                "READ_COMMAND_ACCEPTED",
                busy == 1'b1
            );

            check(
                "READ_ACCEPT_REMOVES_READY",
                cmd_ready == 1'b0
            );

            @(negedge clk);

            cmd_valid = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Attempt a command while the fault manager has blocked service.
     * ================================================================
     */
    task automatic attempt_blocked_command(
        input string tag
    );
        begin

            @(negedge clk);

            cmd_rw    = 1'b0;
            cmd_wdata = 8'hEE;
            cmd_valid = 1'b1;

            @(posedge clk);
            #1;

            check(
                $sformatf(
                    "%s_EXTERNAL_READY_BLOCKED",
                    tag
                ),
                cmd_ready == 1'b0
            );

            check(
                $sformatf(
                    "%s_CORE_CMD_VALID_MASKED",
                    tag
                ),
                dut.core_cmd_valid == 1'b0
            );

            @(posedge clk);
            #1;

            check(
                $sformatf(
                    "%s_STILL_NOT_ACCEPTED",
                    tag
                ),
                cmd_ready == 1'b0
            );

            check(
                $sformatf(
                    "%s_CORE_STILL_MASKED",
                    tag
                ),
                dut.core_cmd_valid == 1'b0
            );

            @(negedge clk);

            cmd_valid = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Common bus capture / ACK model
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

                captured_byte[bit_number] =
                    sda_bus;

            end

        end

    endtask


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

            check(
                "MASTER_RELEASES_SDA_FOR_TARGET_ACK",
                sda_drive_low == 1'b0
            );

            @(negedge scl_bus);
            #1;

            target_sda_hold_low = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Read-target data model
     * ================================================================
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
                 * data 0 -> target pulls SDA LOW
                 * data 1 -> target releases SDA
                 */
                target_sda_hold_low =
                    ~data[bit_number];

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

            target_sda_hold_low = 1'b0;

        end

    endtask


    /*
     * ================================================================
     * Complete one successful normal WRITE transaction
     * ================================================================
     */
    task automatic complete_successful_write(
        input logic [7:0] data,
        input string tag
    );

        integer done_before;

        begin

            done_before =
                done_event_count;

            issue_write(data);


            /*
             * Address = 0x50, write bit = 0:
             *
             *     0xA0
             */
            capture_bus_byte();

            check(
                $sformatf(
                    "%s_ADDRESS_BYTE_A0",
                    tag
                ),
                captured_byte == 8'hA0
            );

            target_ack();


            capture_bus_byte();

            check(
                $sformatf(
                    "%s_DATA_BYTE_MATCH",
                    tag
                ),
                captured_byte == data
            );

            target_ack();


            guard = 0;

            while (done !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 1000) begin

                    $fatal(
                        1,
                        "%s timed out waiting for WRITE done",
                        tag
                    );

                end

            end


            #1;

            check(
                $sformatf(
                    "%s_DONE_ASSERTED",
                    tag
                ),
                done == 1'b1
            );

            check(
                $sformatf(
                    "%s_BUSY_CLEARED",
                    tag
                ),
                busy == 1'b0
            );

            check(
                $sformatf(
                    "%s_NACK_CLEAR",
                    tag
                ),
                nack == 1'b0
            );

            check(
                $sformatf(
                    "%s_DONE_COUNT_INCREMENTED_ONCE",
                    tag
                ),
                done_event_count ==
                (done_before + 1)
            );

            check(
                $sformatf(
                    "%s_LINES_RELEASED",
                    tag
                ),
                (
                    sda_drive_low == 1'b0 &&
                    scl_drive_low == 1'b0
                )
            );


            @(posedge clk);
            #1;

            check(
                $sformatf(
                    "%s_DONE_ONE_CLOCK_PULSE",
                    tag
                ),
                done == 1'b0
            );


            guard = 0;

            while (cmd_ready !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 500) begin

                    $fatal(
                        1,
                        "%s timed out waiting for post-WRITE tBUF",
                        tag
                    );

                end

            end


            check(
                $sformatf(
                    "%s_READY_AFTER_TBUF",
                    tag
                ),
                cmd_ready == 1'b1
            );

            check(
                $sformatf(
                    "%s_NO_ACTIVE_FAULT_AFTER_ACCEPTED_COMMAND",
                    tag
                ),
                fault_active == 1'b0
            );

        end

    endtask


    /*
     * ================================================================
     * Complete one successful normal READ transaction
     * ================================================================
     */
    task automatic complete_successful_read(
        input logic [7:0] target_data,
        input string tag
    );

        integer done_before;

        begin

            done_before =
                done_event_count;

            issue_read();


            /*
             * Address = 0x50, read bit = 1:
             *
             *     0xA1
             */
            capture_bus_byte();

            check(
                $sformatf(
                    "%s_ADDRESS_BYTE_A1",
                    tag
                ),
                captured_byte == 8'hA1
            );


            target_ack();


            /*
             * Target supplies the requested byte.
             */
            target_send_byte(
                target_data
            );


            /*
             * Ninth clock after the eight read-data bits:
             *
             * single-byte read policy => master NACKs by releasing SDA.
             */
            @(posedge scl_bus);
            #1;

            check(
                $sformatf(
                    "%s_MASTER_NACK_RELEASES_SDA",
                    tag
                ),
                sda_drive_low == 1'b0
            );

            check(
                $sformatf(
                    "%s_MASTER_NACK_BUS_HIGH",
                    tag
                ),
                sda_bus == 1'b1
            );


            @(negedge scl_bus);
            #1;


            guard = 0;

            while (done !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 1000) begin

                    $fatal(
                        1,
                        "%s timed out waiting for READ done",
                        tag
                    );

                end

            end


            #1;

            check(
                $sformatf(
                    "%s_READ_DATA_MATCH",
                    tag
                ),
                read_data == target_data
            );

            check(
                $sformatf(
                    "%s_DONE_ASSERTED",
                    tag
                ),
                done == 1'b1
            );

            check(
                $sformatf(
                    "%s_BUSY_CLEARED",
                    tag
                ),
                busy == 1'b0
            );

            check(
                $sformatf(
                    "%s_NACK_STATUS_CLEAR",
                    tag
                ),
                nack == 1'b0
            );

            check(
                $sformatf(
                    "%s_DONE_COUNT_INCREMENTED_ONCE",
                    tag
                ),
                done_event_count ==
                (done_before + 1)
            );


            @(posedge clk);
            #1;

            check(
                $sformatf(
                    "%s_DONE_ONE_CLOCK_PULSE",
                    tag
                ),
                done == 1'b0
            );


            guard = 0;

            while (cmd_ready !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 500) begin

                    $fatal(
                        1,
                        "%s timed out waiting for post-READ tBUF",
                        tag
                    );

                end

            end


            check(
                $sformatf(
                    "%s_READY_AFTER_TBUF",
                    tag
                ),
                cmd_ready == 1'b1
            );

        end

    endtask


    /*
     * ================================================================
     * TEST 1 — normal wrapper behavior
     * ================================================================
     *
     * This proves the fault-aware wrapper has not changed the common
     * protocol path when no faults are present.
     */
    task automatic test_normal_write_read;
        begin

            $display("");
            $display(
                "===== TEST NORMAL WRITE / READ THROUGH FAULT-AWARE WRAPPER ====="
            );

            reset_dut();


            complete_successful_write(
                8'hA5,
                "NORMAL_WRITE"
            );


            check(
                "NORMAL_WRITE_NO_FAULT",
                fault_active == 1'b0
            );

            check(
                "NORMAL_WRITE_NO_RECOVERY",
                recovery_active == 1'b0
            );


            complete_successful_read(
                8'h5A,
                "NORMAL_READ"
            );


            check(
                "NORMAL_READ_NO_FAULT",
                fault_active == 1'b0
            );

            check(
                "NORMAL_READ_NO_RECOVERY",
                recovery_active == 1'b0
            );

            check(
                "NORMAL_PATH_NO_ABORTS",
                abort_event_count == 0
            );

        end

    endtask


    /*
     * ================================================================
     * TEST 2 — autonomous F1 through complete wrapper
     * ================================================================
     */
    task automatic test_f1_wrapper_recovery;
        begin

            $display("");
            $display(
                "===== TEST F1 AUTONOMOUS WRAPPER RECOVERY ====="
            );

            reset_dut();


            /*
             * Free bus is expected, SCL remains HIGH, but an external
             * fault holds SDA LOW.
             */
            @(negedge clk);

            fault_sda_hold_low = 1'b1;


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01)
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 200) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F1 classification"
                    );

                end

            end


            check(
                "WRAPPER_F1_CLASSIFIED",
                fault_active &&
                (fault_code == 2'b01)
            );


            guard = 0;

            while (recovery_active !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 100) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F1 recovery"
                    );

                end

            end


            check(
                "WRAPPER_F1_RECOVERY_ACTIVE",
                recovery_active == 1'b1
            );

            check(
                "WRAPPER_F1_COMMAND_READY_BLOCKED",
                cmd_ready == 1'b0
            );

            check(
                "WRAPPER_F1_MANAGER_OWNS_BUS",
                dut.manager_recovery_owns_bus == 1'b1
            );


            /*
             * Two things happen concurrently:
             *
             * 1. Attempt a command during recovery and prove masking.
             * 2. Release SDA during recovery pulse 3.
             */
            fork

                begin

                    wait (
                        recovery_scl_low_edge_count >= 1
                    );

                    attempt_blocked_command(
                        "WRAPPER_F1"
                    );

                end

                begin

                    wait (
                        recovery_scl_low_edge_count >= 3
                    );

                    @(negedge clk);

                    fault_sda_hold_low = 1'b0;

                end

            join


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01) &&
                    !recovery_active
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 3000) begin

                    $fatal(
                        1,
                        "Timed out waiting for successful wrapper F1 recovery"
                    );

                end

            end


            check(
                "WRAPPER_F1_EXACTLY_NINE_RECOVERY_LOW_PULSES",
                recovery_scl_low_edge_count == 9
            );

            check(
                "WRAPPER_F1_SINGLE_CORE_ABORT",
                abort_event_count == 1
            );

            check(
                "WRAPPER_F1_NO_FALSE_DONE",
                done_event_count == 0
            );

            check(
                "WRAPPER_F1_BUSY_CLEAR_AFTER_RECOVERY",
                busy == 1'b0
            );

            check(
                "WRAPPER_F1_SUCCESS_STATUS_LATCHED",
                fault_active &&
                (fault_code == 2'b01)
            );

            check(
                "WRAPPER_F1_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "WRAPPER_F1_OWNERSHIP_RETURNED",
                dut.manager_recovery_owns_bus == 1'b0
            );


            /*
             * Fresh normal transaction after recovery.
             *
             * Acceptance of this command must clear historical F1 status.
             */
            complete_successful_write(
                8'hA5,
                "F1_POST_RECOVERY_WRITE"
            );


            check(
                "WRAPPER_F1_POST_RECOVERY_SERVICE_RESTORED",
                cmd_ready == 1'b1
            );

            check(
                "WRAPPER_F1_POST_COMMAND_STATUS_CLEARED",
                !fault_active &&
                (fault_code == 2'b00)
            );

        end

    endtask


    /*
     * ================================================================
     * TEST 3 — F2 during a real active wrapper transaction
     * ================================================================
     */
    task automatic test_f2_active_transaction;
        begin

            $display("");
            $display(
                "===== TEST F2 ACTIVE TRANSACTION THROUGH WRAPPER ====="
            );

            reset_dut();


            /*
             * Start a real WRITE transaction.
             *
             * We intentionally do not ACK it because F2 will abort the
             * transaction during the address phase.
             */
            issue_write(
                8'hC3
            );


            /*
             * Wait for the controller to begin a legitimate SCL LOW
             * interval, then externally hold SCL LOW.
             */
            @(posedge dut.core_scl_drive_low);

            @(negedge clk);

            fault_scl_hold_low = 1'b1;


            /*
             * Wait until the common core itself releases SCL and is
             * waiting for physical SCL HIGH.
             */
            guard = 0;

            while (
                !(
                    dut.core_waiting_for_scl_high &&
                    !dut.core_scl_drive_low &&
                    !scl_bus
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 300) begin

                    $fatal(
                        1,
                        "Timed out waiting for active-transaction F2 context"
                    );

                end

            end


            check(
                "WRAPPER_F2_PHYSICAL_SCL_EXTERNALLY_LOW",
                scl_bus == 1'b0
            );

            check(
                "WRAPPER_F2_CORE_RELEASED_SCL",
                dut.core_scl_drive_low == 1'b0
            );


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b10)
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 300) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F2 classification"
                    );

                end

            end


            guard = 0;

            while (recovery_active !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 50) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F2 containment"
                    );

                end

            end


            check(
                "WRAPPER_F2_CODE_SCL_STALL",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "WRAPPER_F2_BUSY_PRESERVED_AFTER_CORE_ABORT",
                busy == 1'b1
            );

            check(
                "WRAPPER_F2_COMMANDS_BLOCKED",
                cmd_ready == 1'b0
            );

            check(
                "WRAPPER_F2_OWNS_BUS",
                dut.manager_recovery_owns_bus == 1'b1
            );

            check(
                "WRAPPER_F2_RELEASES_SCL_OUTPUT",
                scl_drive_low == 1'b0
            );

            check(
                "WRAPPER_F2_RELEASES_SDA_OUTPUT",
                sda_drive_low == 1'b0
            );

            check(
                "WRAPPER_F2_NO_PREMATURE_DONE",
                done_event_count == 0
            );

            check(
                "WRAPPER_F2_SINGLE_CORE_ABORT",
                abort_event_count == 1
            );

            check(
                "WRAPPER_F2_NACK_NOT_OVERLOADED",
                nack == 1'b0
            );


            attempt_blocked_command(
                "WRAPPER_F2"
            );


            /*
             * Extended external hold must preserve containment and busy.
             */
            wait_cycles(
                F2_LIMIT + 5
            );


            check(
                "WRAPPER_F2_EXTENDED_HOLD_RECOVERY_ACTIVE",
                recovery_active == 1'b1
            );

            check(
                "WRAPPER_F2_EXTENDED_HOLD_BUSY_PRESERVED",
                busy == 1'b1
            );

            check(
                "WRAPPER_F2_EXTENDED_HOLD_NO_DONE",
                done_event_count == 0
            );


            /*
             * External device finally releases SCL.
             */
            @(negedge clk);

            fault_scl_hold_low = 1'b0;


            guard = 0;

            while (done !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 3000) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F2 completion"
                    );

                end

            end


            #1;

            check(
                "WRAPPER_F2_DONE_AFTER_CONTAINMENT",
                done == 1'b1
            );

            check(
                "WRAPPER_F2_EXACTLY_ONE_DONE",
                done_event_count == 1
            );

            check(
                "WRAPPER_F2_BUSY_RELEASED_AT_COMPLETION",
                busy == 1'b0
            );

            check(
                "WRAPPER_F2_RECOVERY_INACTIVE",
                recovery_active == 1'b0
            );

            check(
                "WRAPPER_F2_STATUS_LATCHED",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "WRAPPER_F2_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "WRAPPER_F2_OWNERSHIP_RETURNED",
                dut.manager_recovery_owns_bus == 1'b0
            );


            @(posedge clk);
            #1;

            check(
                "WRAPPER_F2_DONE_ONE_CLOCK_PULSE",
                done == 1'b0
            );


            wait_cycles(5);


            check(
                "WRAPPER_F2_NO_DELAYED_SECOND_DONE",
                done_event_count == 1
            );


            /*
             * Fresh transaction after containment.
             */
            complete_successful_write(
                8'h3C,
                "F2_POST_CONTAINMENT_WRITE"
            );


            check(
                "WRAPPER_F2_POST_COMMAND_STATUS_CLEARED",
                !fault_active &&
                (fault_code == 2'b00)
            );

        end

    endtask


    /*
     * ================================================================
     * TEST 4 — F1 -> F2 compound preemption through wrapper
     * ================================================================
     */
    task automatic test_f1_to_f2_wrapper;
        begin

            $display("");
            $display(
                "===== TEST F1 TO F2 PREEMPTION THROUGH WRAPPER ====="
            );

            reset_dut();


            /*
             * Launch autonomous F1.
             */
            @(negedge clk);

            fault_sda_hold_low = 1'b1;


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b01)
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 200) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper compound F1"
                    );

                end

            end


            guard = 0;

            while (recovery_active !== 1'b1) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 100) begin

                    $fatal(
                        1,
                        "Timed out waiting for compound F1 recovery"
                    );

                end

            end


            check(
                "WRAPPER_F12_STARTS_AS_F1",
                fault_active &&
                (fault_code == 2'b01)
            );


            /*
             * Stall the very first F1 recovery clock.
             */
            wait (
                recovery_scl_low_edge_count >= 1
            );


            @(negedge clk);

            fault_scl_hold_low = 1'b1;


            /*
             * The manager releases SCL, but physical SCL remains LOW.
             */
            guard = 0;

            while (
                !(
                    dut.manager_recovery_owns_bus &&
                    !scl_drive_low &&
                    !scl_bus
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 200) begin

                    $fatal(
                        1,
                        "Timed out waiting for compound F1 SCL release"
                    );

                end

            end


            guard = 0;

            while (
                !(
                    fault_active &&
                    (fault_code == 2'b10)
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 300) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper F1-to-F2 reclassification"
                    );

                end

            end


            check(
                "WRAPPER_F12_RECLASSIFIED_TO_F2",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "WRAPPER_F12_FIRST_F1_CLOCK_NOT_COMPLETED",
                dut.u_fault_manager.recovery_pulse_count == 4'd0
            );

            check(
                "WRAPPER_F12_ONLY_ONE_F1_LOW_PULSE_STARTED",
                recovery_scl_low_edge_count == 1
            );

            check(
                "WRAPPER_F12_NO_SECOND_ABORT",
                abort_event_count == 1
            );

            check(
                "WRAPPER_F12_NO_SYNTHETIC_BUSY",
                busy == 1'b0
            );

            check(
                "WRAPPER_F12_NO_SYNTHETIC_DONE",
                done_event_count == 0
            );

            check(
                "WRAPPER_F12_COMMANDS_BLOCKED",
                cmd_ready == 1'b0
            );

            check(
                "WRAPPER_F12_RECOVERY_OWNS_BUS",
                dut.manager_recovery_owns_bus == 1'b1
            );

            check(
                "WRAPPER_F12_CONTROLLER_RELEASES_SCL",
                scl_drive_low == 1'b0
            );

            check(
                "WRAPPER_F12_CONTROLLER_RELEASES_SDA",
                sda_drive_low == 1'b0
            );


            attempt_blocked_command(
                "WRAPPER_F12"
            );


            /*
             * Hold SCL LOW for additional cycles and prove that no more
             * F1 recovery clocks are generated.
             */
            wait_cycles(
                F2_LIMIT + 5
            );


            check(
                "WRAPPER_F12_NO_MORE_F1_CLOCKS",
                recovery_scl_low_edge_count == 1
            );

            check(
                "WRAPPER_F12_STILL_NO_DONE",
                done_event_count == 0
            );


            /*
             * Release SCL but retain original SDA fault.
             */
            @(negedge clk);

            fault_scl_hold_low = 1'b0;


            wait_cycles(6);


            check(
                "WRAPPER_F12_SCL_RELEASED_HIGH",
                scl_bus == 1'b1
            );

            check(
                "WRAPPER_F12_SDA_STILL_LOW",
                sda_bus == 1'b0
            );

            check(
                "WRAPPER_F12_SDA_LOW_PREVENTS_COMPLETION",
                recovery_active == 1'b1
            );

            check(
                "WRAPPER_F12_STILL_BLOCKED_WITH_SDA_LOW",
                cmd_ready == 1'b0
            );


            /*
             * Release SDA and allow fresh continuous bus-free tBUF.
             */
            @(negedge clk);

            fault_sda_hold_low = 1'b0;


            guard = 0;

            while (
                !(
                    !recovery_active &&
                    !dut.manager_recovery_owns_bus
                )
            ) begin

                @(posedge clk);
                #1;

                guard = guard + 1;

                if (guard > 3000) begin

                    $fatal(
                        1,
                        "Timed out waiting for wrapper compound containment completion"
                    );

                end

            end


            check(
                "WRAPPER_F12_RETURNED_TO_SERVICE_STATE",
                !recovery_active &&
                !dut.manager_recovery_owns_bus
            );

            check(
                "WRAPPER_F12_FINAL_CODE_IS_F2",
                fault_active &&
                (fault_code == 2'b10)
            );

            check(
                "WRAPPER_F12_RECOVERY_FAILED_CLEAR",
                recovery_failed == 1'b0
            );

            check(
                "WRAPPER_F12_NEVER_GENERATED_DONE",
                done_event_count == 0
            );

            check(
                "WRAPPER_F12_SINGLE_ABORT_TOTAL",
                abort_event_count == 1
            );

            check(
                "WRAPPER_F12_NO_RESTARTED_F1_CLOCKS",
                recovery_scl_low_edge_count == 1
            );


            /*
             * Fresh transaction after compound recovery.
             */
            complete_successful_write(
                8'h96,
                "F12_POST_RECOVERY_WRITE"
            );


            check(
                "WRAPPER_F12_POST_RECOVERY_STATUS_CLEARED",
                !fault_active &&
                (fault_code == 2'b00)
            );

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
            "S6.5 fault-aware wrapper integration watchdog expired"
        );

    end


    /*
     * ================================================================
     * Main regression
     * ================================================================
     */
    initial begin

        clk = 1'b0;
        rst_n = 1'b0;

        cmd_valid = 1'b0;
        cmd_rw = 1'b0;
        cmd_addr = 7'h50;
        cmd_wdata = 8'h00;

        target_sda_hold_low = 1'b0;
        target_scl_hold_low = 1'b0;

        fault_sda_hold_low = 1'b0;
        fault_scl_hold_low = 1'b0;

        captured_byte = 8'h00;

        error_count = 0;

        done_event_count = 0;
        abort_event_count = 0;
        recovery_scl_low_edge_count = 0;


        test_normal_write_read();

        test_f1_wrapper_recovery();

        test_f2_active_transaction();

        test_f1_to_f2_wrapper();


        $display("");
        $display(
            "============================================"
        );

        if (error_count == 0) begin

            $display(
                "S6.5 FAULT-AWARE WRAPPER INTEGRATION TEST : PASS"
            );

            $display(
                "ERROR COUNT = 0"
            );

        end
        else begin

            $display(
                "S6.5 FAULT-AWARE WRAPPER INTEGRATION TEST : FAIL"
            );

            $display(
                "ERROR COUNT = %0d",
                error_count
            );

            $fatal(
                1,
                "S6.5 wrapper integration verification failed"
            );

        end

        $display(
            "============================================"
        );

        $finish;

    end

endmodule