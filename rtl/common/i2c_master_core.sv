`timescale 1ns/1ps

module i2c_master_core #(
    parameter integer SYS_CLK_HZ = 100_000_000,
    parameter integer I2C_CLK_HZ = 100_000
) (
    input  logic       clk,
    input  logic       rst_n,

    input  logic       cmd_valid,
    output logic       cmd_ready,

    input  logic       cmd_rw,
    input  logic [6:0] cmd_addr,
    input  logic [7:0] cmd_wdata,

    output logic [7:0] read_data,
    output logic       busy,
    output logic       done,
    output logic       nack,

    input  logic       sda_in,
    input  logic       scl_in,

    output logic       sda_drive_low,
    output logic       scl_drive_low,

    input  logic       fault_abort,

    output logic       expect_bus_free,
    output logic       waiting_for_scl_high,
    output logic       transaction_active
);

    /*
     * ================================================================
     * Timing parameters
     * ================================================================
     *
     * Frozen primary configuration:
     *
     * SYS_CLK_HZ = 100 MHz
     * I2C_CLK_HZ = 100 kHz
     */

    localparam integer HALF_PERIOD_CYCLES =
        SYS_CLK_HZ / (2 * I2C_CLK_HZ);

    /*
     * Standard-mode tBUF minimum = 4.7 us.
     *
     * At 100 MHz:
     *
     * 100 clocks/us * 4.7 us = 470 system-clock cycles.
     *
     * The current project validates the frozen 100-MHz configuration.
     */
    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;

    /*
     * ================================================================
     * Transaction state
     * ================================================================
     */

    typedef enum logic [3:0] {
        ST_IDLE,
        ST_START,
        ST_SEND_ADDR,
        ST_ADDR_ACK,
        ST_WRITE_DATA,
        ST_WRITE_ACK,
        ST_READ_DATA,
        ST_MASTER_NACK,
        ST_STOP,
        ST_DONE
    } transaction_state_t;

    transaction_state_t state;

    /*
     * ================================================================
     * Bit/timing phase
     * ================================================================
     */

    typedef enum logic [1:0] {
        PH_LOW_SETUP,
        PH_RELEASE_HIGH,
        PH_HIGH_HOLD,
        PH_RETURN_LOW
    } bit_phase_t;

    bit_phase_t bit_phase;

    /*
     * ================================================================
     * Internal registers
     * ================================================================
     */

    logic [7:0] tx_shift;
    logic [7:0] rx_shift;

    logic [3:0] bit_index;

    logic [31:0] timing_counter;
    logic [31:0] bus_free_counter;

    logic       latched_rw;
    logic [6:0] latched_addr;
    logic [7:0] latched_wdata;

    /*
     * ================================================================
     * Command-ready qualification
     * ================================================================
     *
     * A new command may be accepted only after the bus has remained
     * continuously free for the required tBUF interval.
     *
     * Command acceptance itself is added in S5.3 with START generation.
     */

    always_comb begin
        cmd_ready =
            (state == ST_IDLE) &&
            (bus_free_counter >= T_BUF_CYCLES);
    end

    /*
     * ================================================================
     * Sequential control
     * ================================================================
     */

    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state                  <= ST_IDLE;
            bit_phase              <= PH_LOW_SETUP;

            tx_shift               <= 8'h00;
            rx_shift               <= 8'h00;
            bit_index              <= 4'd0;

            timing_counter         <= 32'd0;
            bus_free_counter       <= 32'd0;

            latched_rw             <= 1'b0;
            latched_addr           <= 7'h00;
            latched_wdata          <= 8'h00;

            read_data              <= 8'h00;

            busy                   <= 1'b0;
            done                   <= 1'b0;
            nack                   <= 1'b0;

            sda_drive_low          <= 1'b0;
            scl_drive_low          <= 1'b0;

            expect_bus_free        <= 1'b1;
            waiting_for_scl_high   <= 1'b0;
            transaction_active     <= 1'b0;

        end
        else begin

            /*
             * done is a pulse in the final implementation.
             */
            done <= 1'b0;

            /*
             * Baseline ties fault_abort LOW.
             *
             * This hook is retained so the S6 fault-aware wrapper can
             * safely terminate the common protocol engine.
             */
            if (fault_abort) begin

                state                <= ST_IDLE;
                bit_phase            <= PH_LOW_SETUP;

                timing_counter       <= 32'd0;
                bus_free_counter     <= 32'd0;

                busy                 <= 1'b0;
                nack                 <= 1'b0;

                sda_drive_low        <= 1'b0;
                scl_drive_low        <= 1'b0;

                expect_bus_free      <= 1'b1;
                waiting_for_scl_high <= 1'b0;
                transaction_active   <= 1'b0;

            end
            else begin

                case (state)

                    /*
                     * ====================================================
                     * IDLE / BUS-FREE QUALIFICATION
                     * ====================================================
                     */

                    ST_IDLE: begin

                        busy                 <= 1'b0;
                        transaction_active   <= 1'b0;

                        expect_bus_free      <= 1'b1;
                        waiting_for_scl_high <= 1'b0;

                        /*
                         * Open-drain idle state:
                         *
                         * 0 means RELEASE.
                         */
                        sda_drive_low <= 1'b0;
                        scl_drive_low <= 1'b0;

                        timing_counter <= 32'd0;

                        /*
                         * tBUF requires continuous bus-free observation.
                         *
                         * Any LOW level resets qualification.
                         */
                        if (sda_in && scl_in) begin

                            if (bus_free_counter < T_BUF_CYCLES)
                                bus_free_counter <=
                                    bus_free_counter + 1'b1;
                            else
                                bus_free_counter <=
                                    bus_free_counter;

                        end
                        else begin

                            bus_free_counter <= 32'd0;

                        end

                    end

                    /*
                     * Remaining transaction states are deliberately
                     * unreachable in S5.2A.
                     *
                     * START generation and command acceptance are added
                     * only after the IDLE/bus-free behavior passes.
                     */

                    default: begin

                        state                <= ST_IDLE;
                        bit_phase            <= PH_LOW_SETUP;

                        timing_counter       <= 32'd0;
                        bus_free_counter     <= 32'd0;

                        busy                 <= 1'b0;

                        sda_drive_low        <= 1'b0;
                        scl_drive_low        <= 1'b0;

                        expect_bus_free      <= 1'b1;
                        waiting_for_scl_high <= 1'b0;
                        transaction_active   <= 1'b0;

                    end

                endcase

            end

        end

    end

endmodule