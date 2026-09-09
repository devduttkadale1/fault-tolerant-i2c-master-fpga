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
     * Timing
     * ================================================================
     */

    localparam integer HALF_PERIOD_CYCLES =
        SYS_CLK_HZ / (2 * I2C_CLK_HZ);

    /*
     * Standard-mode minimum tBUF = 4.7 us.
     * Frozen configuration: 100 MHz -> 470 cycles.
     */
    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;

    /*
     * ================================================================
     * Transaction FSM
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
     * Bit timing phases
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
             * done is a one-cycle pulse in the completed design.
             */
            done <= 1'b0;

            /*
             * S6 fault-aware integration hook.
             * Baseline permanently drives fault_abort LOW.
             */
            if (fault_abort) begin

                state                  <= ST_IDLE;
                bit_phase              <= PH_LOW_SETUP;

                timing_counter         <= 32'd0;
                bus_free_counter       <= 32'd0;

                busy                   <= 1'b0;
                nack                   <= 1'b0;

                sda_drive_low          <= 1'b0;
                scl_drive_low          <= 1'b0;

                expect_bus_free        <= 1'b1;
                waiting_for_scl_high   <= 1'b0;
                transaction_active     <= 1'b0;

            end
            else begin

                case (state)

                    /*
                     * ====================================================
                     * IDLE / BUS-FREE QUALIFICATION
                     * ====================================================
                     */

                    ST_IDLE: begin

                        busy                   <= 1'b0;
                        transaction_active     <= 1'b0;
                        expect_bus_free        <= 1'b1;
                        waiting_for_scl_high   <= 1'b0;

                        sda_drive_low          <= 1'b0;
                        scl_drive_low          <= 1'b0;

                        timing_counter         <= 32'd0;

                        /*
                         * Bus must remain continuously HIGH/HIGH for tBUF.
                         */
                        if (sda_in && scl_in) begin

                            if (bus_free_counter < T_BUF_CYCLES)
                                bus_free_counter <=
                                    bus_free_counter + 1'b1;

                        end
                        else begin

                            bus_free_counter <= 32'd0;

                        end

                        /*
                         * Command acceptance.
                         *
                         * Guard actual bus inputs as well as cmd_ready so
                         * a newly disturbed bus cannot be accepted.
                         */
                        if (
                            cmd_valid &&
                            cmd_ready &&
                            sda_in &&
                            scl_in
                        ) begin

                            latched_rw       <= cmd_rw;
                            latched_addr     <= cmd_addr;
                            latched_wdata    <= cmd_wdata;

                            /*
                             * Address byte:
                             *
                             * [7:1] = 7-bit address
                             * [0]   = R/W
                             */
                            tx_shift         <= {cmd_addr, cmd_rw};
                            bit_index        <= 4'd7;

                            busy             <= 1'b1;
                            nack             <= 1'b0;

                            transaction_active <= 1'b1;
                            expect_bus_free    <= 1'b0;

                            bus_free_counter <= 32'd0;
                            timing_counter   <= 32'd0;

                            /*
                             * Generate START:
                             *
                             * SDA HIGH -> LOW while actual SCL is HIGH.
                             */
                            sda_drive_low    <= 1'b1;
                            scl_drive_low    <= 1'b0;

                            state            <= ST_START;

                        end

                    end

                    /*
                     * ====================================================
                     * START HOLD
                     * ====================================================
                     *
                     * START was generated when command acceptance pulled
                     * SDA LOW while SCL was HIGH.
                     *
                     * Hold the START condition before beginning the first
                     * SCL LOW interval.
                     */

                    ST_START: begin

                        busy                   <= 1'b1;
                        transaction_active     <= 1'b1;
                        expect_bus_free        <= 1'b0;

                        sda_drive_low          <= 1'b1;
                        scl_drive_low          <= 1'b0;

                        /*
                         * If actual SCL is unexpectedly held LOW while the
                         * controller has released it, wait for it to return
                         * HIGH rather than forcing HIGH.
                         */
                        if (!scl_in) begin

                            waiting_for_scl_high <= 1'b1;
                            timing_counter       <= 32'd0;

                        end
                        else begin

                            waiting_for_scl_high <= 1'b0;

                            if (
                                timing_counter >=
                                (HALF_PERIOD_CYCLES - 1)
                            ) begin

                                timing_counter <= 32'd0;

                                /*
                                 * Begin first address-bit LOW interval.
                                 */
                                scl_drive_low  <= 1'b1;

                                /*
                                 * Open drain:
                                 * bit 0 -> drive LOW
                                 * bit 1 -> release
                                 */
                                sda_drive_low  <= ~tx_shift[7];

                                bit_index      <= 4'd7;
                                bit_phase      <= PH_LOW_SETUP;
                                state          <= ST_SEND_ADDR;

                            end
                            else begin

                                timing_counter <=
                                    timing_counter + 1'b1;

                            end

                        end

                    end

                    /*
                     * ====================================================
                     * ADDRESS TRANSMISSION
                     * ====================================================
                     *
                     * This stage introduces the real reusable bit-timing
                     * engine.
                     *
                     * S5.2B validates START, LOW timing, SCL release,
                     * actual-SCL observation, clock stretching and HIGH
                     * timing.
                     *
                     * S5.3 will implement the address ACK state.
                     */

                    ST_SEND_ADDR: begin

                        busy                   <= 1'b1;
                        transaction_active     <= 1'b1;
                        expect_bus_free        <= 1'b0;

                        case (bit_phase)

                            /*
                             * --------------------------------------------
                             * LOW + DATA SETUP
                             * --------------------------------------------
                             */

                            PH_LOW_SETUP: begin

                                scl_drive_low        <= 1'b1;
                                sda_drive_low        <=
                                    ~tx_shift[bit_index];

                                waiting_for_scl_high <= 1'b0;

                                if (
                                    timing_counter >=
                                    (HALF_PERIOD_CYCLES - 1)
                                ) begin

                                    timing_counter       <= 32'd0;

                                    /*
                                     * Release SCL.
                                     *
                                     * HIGH timing must NOT start until
                                     * actual scl_in is observed HIGH.
                                     */
                                    scl_drive_low        <= 1'b0;
                                    waiting_for_scl_high <= 1'b1;
                                    bit_phase            <=
                                        PH_RELEASE_HIGH;

                                end
                                else begin

                                    timing_counter <=
                                        timing_counter + 1'b1;

                                end

                            end

                            /*
                             * --------------------------------------------
                             * RELEASE SCL / CLOCK-STRETCH WAIT
                             * --------------------------------------------
                             */

                            PH_RELEASE_HIGH: begin

                                scl_drive_low        <= 1'b0;
                                sda_drive_low        <=
                                    ~tx_shift[bit_index];

                                timing_counter       <= 32'd0;
                                waiting_for_scl_high <= 1'b1;

                                if (scl_in) begin

                                    waiting_for_scl_high <= 1'b0;
                                    bit_phase            <= PH_HIGH_HOLD;

                                end

                            end

                            /*
                             * --------------------------------------------
                             * ACTUAL SCL HIGH HOLD
                             * --------------------------------------------
                             */

                            PH_HIGH_HOLD: begin

                                scl_drive_low <= 1'b0;
                                sda_drive_low <=
                                    ~tx_shift[bit_index];

                                /*
                                 * If actual SCL ceases to be HIGH, do not
                                 * count that interval as HIGH timing.
                                 */
                                if (!scl_in) begin

                                    timing_counter       <= 32'd0;
                                    waiting_for_scl_high <= 1'b1;
                                    bit_phase            <=
                                        PH_RELEASE_HIGH;

                                end
                                else begin

                                    waiting_for_scl_high <= 1'b0;

                                    if (
                                        timing_counter >=
                                        (HALF_PERIOD_CYCLES - 1)
                                    ) begin

                                        timing_counter <= 32'd0;

                                        /*
                                         * Return SCL LOW.
                                         */
                                        scl_drive_low <= 1'b1;

                                        if (bit_index == 0) begin

                                            /*
                                             * Release SDA for target ACK.
                                             *
                                             * ACK timing is implemented in
                                             * S5.3.
                                             */
                                            sda_drive_low <= 1'b0;
                                            bit_phase     <= PH_LOW_SETUP;
                                            state         <= ST_ADDR_ACK;

                                        end
                                        else begin

                                            bit_index <= bit_index - 1'b1;

                                            sda_drive_low <=
                                                ~tx_shift[bit_index - 1'b1];

                                            bit_phase <= PH_LOW_SETUP;

                                        end

                                    end
                                    else begin

                                        timing_counter <=
                                            timing_counter + 1'b1;

                                    end

                                end

                            end

                            default: begin

                                bit_phase              <= PH_LOW_SETUP;
                                timing_counter         <= 32'd0;
                                waiting_for_scl_high   <= 1'b0;

                                scl_drive_low          <= 1'b1;
                                sda_drive_low          <=
                                    ~tx_shift[bit_index];

                            end

                        endcase

                    end

                    /*
                     * ====================================================
                     * ADDRESS ACK PLACEHOLDER
                     * ====================================================
                     *
                     * Safe temporary endpoint for S5.2B.
                     *
                     * The testbench terminates before depending on this
                     * state. S5.3 replaces this placeholder with the real
                     * ninth-clock ACK sampling sequence.
                     */

                    ST_ADDR_ACK: begin

                        busy                   <= 1'b1;
                        transaction_active     <= 1'b1;
                        expect_bus_free        <= 1'b0;
                        waiting_for_scl_high   <= 1'b0;

                        sda_drive_low          <= 1'b0;
                        scl_drive_low          <= 1'b1;

                        timing_counter         <= 32'd0;

                    end

                    /*
                     * Remaining states are implemented in later S5 steps.
                     */

                    default: begin

                        state                  <= ST_IDLE;
                        bit_phase              <= PH_LOW_SETUP;

                        timing_counter         <= 32'd0;
                        bus_free_counter       <= 32'd0;

                        busy                   <= 1'b0;
                        nack                   <= 1'b0;

                        sda_drive_low          <= 1'b0;
                        scl_drive_low          <= 1'b0;

                        expect_bus_free        <= 1'b1;
                        waiting_for_scl_high   <= 1'b0;
                        transaction_active     <= 1'b0;

                    end

                endcase

            end

        end

    end

endmodule