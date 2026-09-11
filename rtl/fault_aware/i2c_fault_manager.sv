`timescale 1ns/1ps

module i2c_fault_manager #(
    parameter integer SYS_CLK_HZ             = 100_000_000,
    parameter integer I2C_CLK_HZ             = 100_000,
    parameter integer SDA_STUCK_LIMIT_CYCLES = 10_000,
    parameter integer SCL_STALL_LIMIT_CYCLES = 100_000
) (
    input  logic clk,
    input  logic rst_n,

    input  logic cmd_accept,

    input  logic core_expect_bus_free,
    input  logic core_waiting_for_scl_high,
    input  logic core_transaction_active,
    input  logic core_scl_drive_low,

    input  logic sda_in,
    input  logic scl_in,

    output logic fault_abort,
    output logic block_cmd_ready,
    output logic fault_busy_hold,
    output logic fault_done_pulse,

    output logic recovery_owns_bus,
    output logic recovery_sda_drive_low,
    output logic recovery_scl_drive_low,

    output logic       fault_active,
    output logic [1:0] fault_code,
    output logic       recovery_active,
    output logic       recovery_failed
);

    /*
     * ================================================================
     * Frozen fault encoding
     * ================================================================
     */
    localparam logic [1:0] FAULT_NONE      = 2'b00;
    localparam logic [1:0] FAULT_SDA_STUCK = 2'b01;
    localparam logic [1:0] FAULT_SCL_STALL = 2'b10;


    /*
     * ================================================================
     * Timing
     * ================================================================
     */
    localparam integer HALF_PERIOD_CYCLES =
        SYS_CLK_HZ / (2 * I2C_CLK_HZ);

    localparam integer T_BUF_CYCLES =
        (SYS_CLK_HZ / 1_000_000) * 47 / 10;


    /*
     * ================================================================
     * Recovery FSM
     * ================================================================
     */
    typedef enum logic [4:0] {

        RM_IDLE,

        F1_DETECTED,
        F1_PREPARE,
        F1_PULSE_LOW,
        F1_RELEASE_SCL,
        F1_WAIT_SCL_HIGH,
        F1_CHECK_SDA,
        F1_WAIT_BUS_FREE,
        F1_WAIT_TBUF,
        F1_SUCCESS,
        F1_FAILED,

        F2_DETECTED,
        F2_RELEASE_BUS,
        F2_WAIT_SCL_RELEASE,
        F2_WAIT_BUS_FREE,
        F2_WAIT_TBUF,
        F2_SUCCESS

    } recovery_state_t;

    recovery_state_t state;


    /*
     * ================================================================
     * Recovery bookkeeping
     * ================================================================
     */
    logic [31:0] recovery_timing_counter;
    logic [31:0] recovery_tbuf_counter;

    /*
     * Number of fully completed F1 recovery clocks.
     */
    logic [3:0] recovery_pulse_count;

    /*
     * First completed recovery pulse on which SDA was sampled HIGH.
     * Zero means no release has yet been observed.
     */
    logic [3:0] sda_release_pulse;

    /*
     * SDA is sampled at the end of a verified complete SCL HIGH
     * interval. F1_CHECK_SDA processes this captured value.
     */
    logic recovery_sda_sample;

    /*
    * Indicates that the current recovery LOW/HIGH timing phase has
    * actually begun.
    *
    * This avoids counting the same clock edge that changes the physical
    * open-drain output as a complete elapsed timing interval.
     */
    logic recovery_phase_started;

    /*
     * Reserved for S6.3D F2 containment.
     */
    logic f2_aborted_active_transaction;


    /*
     * ================================================================
     * Fault-detector context
     * ================================================================
     */
    logic detector_f1_monitor_enable;
    logic detector_f2_monitor_enable;

    logic detector_expect_bus_free;
    logic detector_waiting_for_scl_high;
    logic detector_scl_drive_low;

    logic f1_detect_pulse;
    logic f2_detect_pulse;


    /*
     * ================================================================
     * Verified detector
     * ================================================================
     */
    i2c_fault_detector #(
        .SDA_STUCK_LIMIT_CYCLES (SDA_STUCK_LIMIT_CYCLES),
        .SCL_STALL_LIMIT_CYCLES (SCL_STALL_LIMIT_CYCLES)
    ) u_fault_detector (
        .clk                  (clk),
        .rst_n                (rst_n),

        .f1_monitor_enable    (detector_f1_monitor_enable),
        .f2_monitor_enable    (detector_f2_monitor_enable),

        .expect_bus_free      (detector_expect_bus_free),
        .waiting_for_scl_high (detector_waiting_for_scl_high),
        .scl_drive_low        (detector_scl_drive_low),

        .sda_in               (sda_in),
        .scl_in               (scl_in),

        .f1_detect_pulse      (f1_detect_pulse),
        .f2_detect_pulse      (f2_detect_pulse)
    );


    /*
     * ================================================================
     * Detector context selection
     * ================================================================
     */
    always_comb begin

        detector_f1_monitor_enable     = 1'b0;
        detector_f2_monitor_enable     = 1'b0;
        detector_expect_bus_free       = 1'b0;
        detector_waiting_for_scl_high  = 1'b0;
        detector_scl_drive_low         = 1'b0;

        case (state)

            /*
             * Normal operation uses common-core context.
             */
            RM_IDLE: begin

                detector_f1_monitor_enable =
                    1'b1;

                detector_f2_monitor_enable =
                    1'b1;

                detector_expect_bus_free =
                    core_expect_bus_free;

                detector_waiting_for_scl_high =
                    core_waiting_for_scl_high;

                detector_scl_drive_low =
                    core_scl_drive_low;

            end


            /*
             * During F1 recovery the F1 detector is disabled.
             *
             * F2 remains enabled specifically while recovery has
             * released SCL and is waiting for actual SCL HIGH.
             */
            F1_WAIT_SCL_HIGH: begin

                detector_f1_monitor_enable =
                    1'b0;

                detector_f2_monitor_enable =
                    1'b1;

                detector_expect_bus_free =
                    1'b0;

                detector_waiting_for_scl_high =
                    1'b1;

                detector_scl_drive_low =
                    1'b0;

            end


            default: begin

                detector_f1_monitor_enable     = 1'b0;
                detector_f2_monitor_enable     = 1'b0;
                detector_expect_bus_free       = 1'b0;
                detector_waiting_for_scl_high  = 1'b0;
                detector_scl_drive_low         = 1'b0;

            end

        endcase

    end


    /*
     * ================================================================
     * Recovery FSM
     * ================================================================
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            state                         <= RM_IDLE;

            recovery_timing_counter       <= 32'd0;
            recovery_tbuf_counter         <= 32'd0;
            recovery_pulse_count          <= 4'd0;
            sda_release_pulse             <= 4'd0;
            recovery_sda_sample           <= 1'b0;
            recovery_phase_started <= 1'b0;

            f2_aborted_active_transaction <= 1'b0;

            fault_abort                   <= 1'b0;

            block_cmd_ready               <= 1'b0;
            fault_busy_hold               <= 1'b0;
            fault_done_pulse              <= 1'b0;

            recovery_owns_bus             <= 1'b0;
            recovery_sda_drive_low        <= 1'b0;
            recovery_scl_drive_low        <= 1'b0;

            fault_active                  <= 1'b0;
            fault_code                    <= FAULT_NONE;

            recovery_active               <= 1'b0;
            recovery_failed               <= 1'b0;

        end
        else begin

            /*
             * One-cycle outputs default LOW.
             */
            fault_abort      <= 1'b0;
            fault_done_pulse <= 1'b0;


            case (state)

                /*
                 * ====================================================
                 * NORMAL MONITORING
                 * ====================================================
                 */
                RM_IDLE: begin

                    block_cmd_ready         <= 1'b0;
                    fault_busy_hold         <= 1'b0;

                    recovery_owns_bus       <= 1'b0;
                    recovery_sda_drive_low  <= 1'b0;
                    recovery_scl_drive_low  <= 1'b0;

                    recovery_active         <= 1'b0;
                    recovery_failed         <= 1'b0;

                    recovery_timing_counter <= 32'd0;
                    recovery_tbuf_counter   <= 32'd0;
                    recovery_pulse_count    <= 4'd0;
                    sda_release_pulse       <= 4'd0;
                    recovery_sda_sample     <= 1'b0;
                    recovery_phase_started <= 1'b0;

                    f2_aborted_active_transaction <= 1'b0;


                    /*
                     * Successful historical fault status remains
                     * visible until a later command is actually
                     * accepted.
                     */
                    if (cmd_accept) begin

                        fault_active <= 1'b0;
                        fault_code   <= FAULT_NONE;

                    end


                    /*
                     * F2 normal-operation handling is implemented in
                     * S6.3D.
                     *
                     * F2 remains explicitly first here to preserve
                     * frozen classification priority.
                     */
                    if (f2_detect_pulse) begin

    /*
     * ========================================================
     * F2 DETECTION
     * ========================================================
     *
     * Capture whether this fault terminated an active normal
     * transaction before fault_abort clears the common core's
     * transaction state.
     */
    f2_aborted_active_transaction <=
        core_transaction_active;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_failed <= 1'b0;

    /*
     * No new command may be accepted once F2 has been
     * classified.
     */
    block_cmd_ready <= 1'b1;

    /*
     * Preserve externally visible busy semantics if an active
     * transaction is being terminated.
     */
    fault_busy_hold <=
        core_transaction_active;

    /*
     * Immediately take ownership and release both open-drain
     * outputs. F2 containment never generates recovery clocks
     * and never attempts to force SCL HIGH.
     */
    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    /*
     * Abort the common core for exactly one cycle.
     *
     * Because fault_abort is registered, the common core sees
     * this pulse on the following active clock edge. Recovery
     * ownership already prevents any normal bus drive from
     * escaping in the meantime.
     */
    fault_abort <= 1'b1;

    recovery_tbuf_counter <= 32'd0;

    state <= F2_DETECTED;

end
else if (f1_detect_pulse) begin

                        fault_active <= 1'b1;
                        fault_code   <= FAULT_SDA_STUCK;

                        block_cmd_ready <= 1'b1;

                        state <= F1_DETECTED;

                    end

                end


                /*
                 * ====================================================
                 * F1 DETECTED
                 * ====================================================
                 *
                 * Take recovery ownership and reset the common core
                 * back to IDLE/released state.
                 */
                F1_DETECTED: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    fault_active <= 1'b1;
                    fault_code   <= FAULT_SDA_STUCK;

                    recovery_active <= 1'b0;
                    recovery_failed <= 1'b0;

                    /*
                     * One-cycle common-core abort/reset.
                     */
                    fault_abort <= 1'b1;

                    state <= F1_PREPARE;

                end


                /*
                 * ====================================================
                 * F1 PREPARE
                 * ====================================================
                 */
                F1_PREPARE: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    fault_active <= 1'b1;
                    fault_code   <= FAULT_SDA_STUCK;

                    recovery_active <= 1'b1;
                    recovery_failed <= 1'b0;

                    recovery_timing_counter <= 32'd0;
                    recovery_tbuf_counter   <= 32'd0;

                    recovery_pulse_count <= 4'd0;
                    sda_release_pulse    <= 4'd0;
                    recovery_sda_sample  <= 1'b0;
                    recovery_phase_started <= 1'b0;

                    state <= F1_PULSE_LOW;

                end


                /*
                 * ====================================================
                 * F1 RECOVERY CLOCK LOW
                 * ====================================================
                 *
                 * SDA remains released.
                 * SCL is actively pulled LOW for one complete
                 * HALF_PERIOD_CYCLES interval.
                 */
                F1_PULSE_LOW: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b1;

                    recovery_active <= 1'b1;
                    recovery_failed <= 1'b0;

                /*
                * The first cycle establishes physical SCL LOW.
                * Timing begins only after that output transition has occurred.
                */
                if (!recovery_phase_started) begin

                    recovery_phase_started  <= 1'b1;
                    recovery_timing_counter <= 32'd0;

                end
                else if (
                    recovery_timing_counter >=
                    (HALF_PERIOD_CYCLES - 1)
                ) begin

                    recovery_timing_counter <= 32'd0;
                    recovery_phase_started  <= 1'b0;

                    /*
                    * The full LOW interval has elapsed.
                    * Release SCL open-drain.
                    */
                    recovery_scl_drive_low <= 1'b0;

                    state <= F1_RELEASE_SCL;

                end
                else begin

                    recovery_timing_counter <=
                        recovery_timing_counter + 1'b1;

                end

                end


                /*
                 * ====================================================
                 * F1 RELEASE SCL
                 * ====================================================
                 *
                 * Releasing SCL does not imply physical SCL HIGH.
                 */
                F1_RELEASE_SCL: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b1;

                    recovery_timing_counter <= 32'd0;
                    recovery_phase_started <= 1'b0;

                    state <= F1_WAIT_SCL_HIGH;

                end


                /*
                 * ====================================================
                 * F1 WAIT FOR ACTUAL SCL HIGH / HIGH HOLD
                 * ====================================================
                 *
                 * HIGH timing is counted only while actual scl_in is
                 * HIGH.
                 *
                 * If scl_in returns LOW before the HIGH interval
                 * completes, the HIGH timing counter restarts.
                 *
                 * F2 monitoring remains enabled in this state.
                 */
                F1_WAIT_SCL_HIGH: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b1;

                    /*
                     * S6.3E will give f2_detect_pulse priority here
                     * and sequentially reclassify F1 as F2.
                     *
                     * Until that stage this branch intentionally
                     * continues only the F1 unit implementation.
                     */
                    if (!scl_in) begin

                /*
                * Physical SCL is not HIGH, so none of this interval may count
                * toward the recovery-clock HIGH period.
                */
                recovery_timing_counter <= 32'd0;
                recovery_phase_started  <= 1'b0;

            end
            else if (!recovery_phase_started) begin

                /*
                * Actual SCL has now been observed HIGH.
                *
                * Establish the beginning of the physical HIGH interval without
                * prematurely counting this observation edge as one elapsed clock
                * period.
                */
                recovery_timing_counter <= 32'd0;
                recovery_phase_started  <= 1'b1;

            end
            else if (
                recovery_timing_counter >=
                (HALF_PERIOD_CYCLES - 1)
            ) begin

                recovery_timing_counter <= 32'd0;
                recovery_phase_started  <= 1'b0;

                /*
                * One complete LOW + HIGH recovery clock has now finished.
                */
                recovery_pulse_count <=
                    recovery_pulse_count + 1'b1;

                /*
                * Capture SDA only after a complete verified physical SCL-HIGH
                * interval.
                */
                recovery_sda_sample <= sda_in;

                state <= F1_CHECK_SDA;

            end
            else begin

                recovery_timing_counter <=
                    recovery_timing_counter + 1'b1;

            end

                            end


                /*
                 * ====================================================
                 * F1 CHECK SDA
                 * ====================================================
                 *
                 * recovery_sda_sample was captured at the end of the
                 * completed HIGH interval, while physical SCL was HIGH.
                 */
                F1_CHECK_SDA: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b1;

                    /*
                     * Record only the first release observation.
                     */
                    if (
                        recovery_sda_sample &&
                        (sda_release_pulse == 4'd0)
                    ) begin

                        sda_release_pulse <=
                            recovery_pulse_count;

                    end


                    /*
                     * Exactly nine complete clocks are required.
                     */
                    if (recovery_pulse_count >= 4'd9) begin

                        if (recovery_sda_sample) begin

                            recovery_tbuf_counter <= 32'd0;

                            state <= F1_WAIT_BUS_FREE;

                        end
                        else begin

                            state <= F1_FAILED;

                        end

                    end
                    else begin

                        /*
                         * Even when SDA releases early, continue the
                         * bus-clear sequence to nine clocks.
                         */
                        recovery_sda_sample <= 1'b0;

                        recovery_timing_counter <= 32'd0;
                        recovery_phase_started <= 1'b0;

                        state <= F1_PULSE_LOW;

                    end

                end


                /*
                 * ====================================================
                 * F1 WAIT FOR ELECTRICAL BUS FREE
                 * ====================================================
                 */
                F1_WAIT_BUS_FREE: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b1;

                    recovery_tbuf_counter <= 32'd0;

                    if (sda_in && scl_in) begin

                        state <= F1_WAIT_TBUF;

                    end

                end


                /*
                 * ====================================================
                 * F1 CONTINUOUS tBUF
                 * ====================================================
                 */
                F1_WAIT_TBUF: begin

                    block_cmd_ready <= 1'b1;

                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b1;

                    if (!(sda_in && scl_in)) begin

                        recovery_tbuf_counter <= 32'd0;

                        state <= F1_WAIT_BUS_FREE;

                    end
                    else if (
                        recovery_tbuf_counter >=
                        (T_BUF_CYCLES - 1)
                    ) begin

                        recovery_tbuf_counter <= 32'd0;

                        state <= F1_SUCCESS;

                    end
                    else begin

                        recovery_tbuf_counter <=
                            recovery_tbuf_counter + 1'b1;

                    end

                end


                /*
                 * ====================================================
                 * F1 SUCCESS
                 * ====================================================
                 */
                F1_SUCCESS: begin

                    /*
                     * Bus lines remain released.
                     */
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b0;
                    recovery_failed <= 1'b0;

                    /*
                     * Previous fault status remains latched until the
                     * next command is actually accepted.
                     */
                    fault_active <= 1'b1;
                    fault_code   <= FAULT_SDA_STUCK;

                    /*
                     * Return ownership and command service.
                     */
                    recovery_owns_bus <= 1'b0;
                    block_cmd_ready   <= 1'b0;

                    /*
                     * Autonomous idle-bus F1 recovery is not a command
                     * completion and therefore never asserts done.
                     */
                    fault_done_pulse <= 1'b0;

                    state <= RM_IDLE;

                end


                /*
                 * ====================================================
                 * F1 FAILED
                 * ====================================================
                 *
                 * Reset-only terminal state.
                 */
                F1_FAILED: begin

                    fault_active <= 1'b1;
                    fault_code   <= FAULT_SDA_STUCK;

                    recovery_active <= 1'b0;
                    recovery_failed <= 1'b1;

                    block_cmd_ready <= 1'b1;
                    fault_busy_hold <= 1'b0;

                    /*
                     * Keep recovery ownership so that the failed
                     * controller cannot accidentally resume protocol
                     * drive activity.
                     *
                     * Both open-drain outputs themselves remain
                     * released.
                     */
                    recovery_owns_bus      <= 1'b1;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    /*
                     * No autonomous command completion.
                     */
                    fault_done_pulse <= 1'b0;

                    state <= F1_FAILED;

                end


                /*
                 * ====================================================
                 * F2 STATES
                 * ====================================================
                 *
                 * Implemented in S6.3D.
                 *
                 * They are not reachable from the S6.3B F1 unit path.
                 */
                /*
 * ============================================================
 * F2 DETECTED
 * ============================================================
 *
 * F2 has already been classified and the common-core abort
 * pulse has already been launched from RM_IDLE.
 */
F2_DETECTED: begin

    block_cmd_ready <= 1'b1;

    fault_busy_hold <=
        f2_aborted_active_transaction;

    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_active <= 1'b0;
    recovery_failed <= 1'b0;

    recovery_tbuf_counter <= 32'd0;

    state <= F2_RELEASE_BUS;

end


/*
 * ============================================================
 * F2 RELEASE BUS
 * ============================================================
 *
 * Both controller outputs remain electrically released.
 * There is no SCL-forcing recovery operation.
 */
F2_RELEASE_BUS: begin

    block_cmd_ready <= 1'b1;

    fault_busy_hold <=
        f2_aborted_active_transaction;

    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_active <= 1'b1;
    recovery_failed <= 1'b0;

    recovery_tbuf_counter <= 32'd0;

    state <= F2_WAIT_SCL_RELEASE;

end


/*
 * ============================================================
 * F2 WAIT FOR EXTERNAL SCL RELEASE
 * ============================================================
 *
 * If another device continues holding SCL LOW, containment
 * remains here indefinitely.
 *
 * The controller must never actively force SCL HIGH.
 */
F2_WAIT_SCL_RELEASE: begin

    block_cmd_ready <= 1'b1;

    fault_busy_hold <=
        f2_aborted_active_transaction;

    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_active <= 1'b1;
    recovery_failed <= 1'b0;

    recovery_tbuf_counter <= 32'd0;

    if (scl_in) begin

        state <= F2_WAIT_BUS_FREE;

    end

end


/*
 * ============================================================
 * F2 WAIT FOR COMPLETE BUS FREE
 * ============================================================
 *
 * Both physical bus lines must be observed HIGH before tBUF
 * qualification begins.
 */
F2_WAIT_BUS_FREE: begin

    block_cmd_ready <= 1'b1;

    fault_busy_hold <=
        f2_aborted_active_transaction;

    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_active <= 1'b1;
    recovery_failed <= 1'b0;

    recovery_tbuf_counter <= 32'd0;

    if (scl_in && sda_in) begin

        state <= F2_WAIT_TBUF;

    end

end


/*
 * ============================================================
 * F2 CONTINUOUS tBUF
 * ============================================================
 */
F2_WAIT_TBUF: begin

    block_cmd_ready <= 1'b1;

    fault_busy_hold <=
        f2_aborted_active_transaction;

    recovery_owns_bus      <= 1'b1;
    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    recovery_active <= 1'b1;
    recovery_failed <= 1'b0;

    /*
     * Any renewed LOW level destroys the current continuous
     * bus-free qualification.
     */
    if (!(scl_in && sda_in)) begin

        recovery_tbuf_counter <= 32'd0;

        state <= F2_WAIT_BUS_FREE;

    end
    else if (
        recovery_tbuf_counter >=
        (T_BUF_CYCLES - 1)
    ) begin

        recovery_tbuf_counter <= 32'd0;

        state <= F2_SUCCESS;

    end
    else begin

        recovery_tbuf_counter <=
            recovery_tbuf_counter + 1'b1;

    end

end


/*
 * ============================================================
 * F2 SUCCESS
 * ============================================================
 *
 * Containment is complete. The original transaction is never
 * automatically retried.
 */
F2_SUCCESS: begin

    recovery_sda_drive_low <= 1'b0;
    recovery_scl_drive_low <= 1'b0;

    recovery_active <= 1'b0;
    recovery_failed <= 1'b0;

    /*
     * Successful historical F2 status remains visible until the
     * next command is actually accepted.
     */
    fault_active <= 1'b1;
    fault_code   <= FAULT_SCL_STALL;

    /*
     * Return normal bus ownership and command service.
     */
    recovery_owns_bus <= 1'b0;
    block_cmd_ready   <= 1'b0;

    /*
     * Frozen active-transaction policy:
     *
     *     containment complete:
     *         busy = 0
     *         done = 1 for one system-clock cycle
     *
     * If there was no active transaction, no completion pulse is
     * invented.
     */
    fault_busy_hold <= 1'b0;

    fault_done_pulse <=
        f2_aborted_active_transaction;

    f2_aborted_active_transaction <= 1'b0;

    state <= RM_IDLE;

end


                /*
                 * ====================================================
                 * DEFENSIVE DEFAULT
                 * ====================================================
                 */
                default: begin

                    state <= RM_IDLE;

                    recovery_timing_counter <= 32'd0;
                    recovery_tbuf_counter   <= 32'd0;

                    recovery_pulse_count <= 4'd0;
                    sda_release_pulse    <= 4'd0;
                    recovery_sda_sample  <= 1'b0;
                    recovery_phase_started <= 1'b0;

                    f2_aborted_active_transaction <= 1'b0;

                    fault_abort      <= 1'b0;
                    fault_busy_hold  <= 1'b0;
                    fault_done_pulse <= 1'b0;

                    recovery_owns_bus      <= 1'b0;
                    recovery_sda_drive_low <= 1'b0;
                    recovery_scl_drive_low <= 1'b0;

                    recovery_active <= 1'b0;

                end

            endcase

        end

    end


    /*
     * ================================================================
     * Parameter sanity
     * ================================================================
     */
    initial begin

        if (SYS_CLK_HZ < 1) begin
            $fatal(1, "SYS_CLK_HZ must be >= 1");
        end

        if (I2C_CLK_HZ < 1) begin
            $fatal(1, "I2C_CLK_HZ must be >= 1");
        end

        if (HALF_PERIOD_CYCLES < 1) begin
            $fatal(1, "HALF_PERIOD_CYCLES must be >= 1");
        end

        if (T_BUF_CYCLES < 1) begin
            $fatal(1, "T_BUF_CYCLES must be >= 1");
        end

    end

endmodule