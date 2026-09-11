`timescale 1ns/1ps

module i2c_fault_detector #(
    parameter integer SDA_STUCK_LIMIT_CYCLES = 10_000,
    parameter integer SCL_STALL_LIMIT_CYCLES = 100_000
) (
    input  logic clk,
    input  logic rst_n,

    /*
     * Independent detector enables.
     *
     * Normal operation:
     *   f1_monitor_enable = 1
     *   f2_monitor_enable = 1
     *
     * F1 recovery:
     *   f1_monitor_enable = 0
     *   f2_monitor_enable = 1 only while recovery is waiting
     *   for released SCL to become actually HIGH.
     *
     * F2 containment / failed recovery:
     *   both disabled.
     */
    input  logic f1_monitor_enable,
    input  logic f2_monitor_enable,

    /*
     * Context supplied by the fault-aware integration layer.
     *
     * In normal operation these come from the proven common core.
     * During F1 recovery, waiting_for_scl_high and scl_drive_low may
     * instead describe the recovery controller's selected bus context.
     */
    input  logic expect_bus_free,
    input  logic waiting_for_scl_high,
    input  logic scl_drive_low,

    /*
     * Actual resolved bus levels.
     */
    input  logic sda_in,
    input  logic scl_in,

    /*
     * One-system-clock detection events.
     *
     * Persistent externally visible fault status belongs to the
     * future fault manager, not this detector.
     */
    output logic f1_detect_pulse,
    output logic f2_detect_pulse
);

    /*
     * ================================================================
     * Counter sizing
     * ================================================================
     */
    localparam integer F1_COUNT_WIDTH =
        (SDA_STUCK_LIMIT_CYCLES <= 1) ?
        1 :
        $clog2(SDA_STUCK_LIMIT_CYCLES);

    localparam integer F2_COUNT_WIDTH =
        (SCL_STALL_LIMIT_CYCLES <= 1) ?
        1 :
        $clog2(SCL_STALL_LIMIT_CYCLES);

    logic [F1_COUNT_WIDTH-1:0] f1_count;
    logic [F2_COUNT_WIDTH-1:0] f2_count;

    logic f1_fired;
    logic f2_fired;

    localparam logic [F1_COUNT_WIDTH-1:0] F1_LAST_COUNT =
        SDA_STUCK_LIMIT_CYCLES - 1;

    localparam logic [F2_COUNT_WIDTH-1:0] F2_LAST_COUNT =
        SCL_STALL_LIMIT_CYCLES - 1;


    /*
     * ================================================================
     * Qualifying conditions
     * ================================================================
     *
     * F1:
     *   monitoring enabled
     *   controller expects free bus
     *   actual SCL HIGH
     *   actual SDA LOW
     *
     * F2:
     *   monitoring enabled
     *   selected controller context expects SCL HIGH
     *   selected controller context is not driving SCL LOW
     *   actual SCL remains LOW
     */
    logic f1_qualifies;
    logic f2_qualifies;

    always_comb begin

        f1_qualifies =
            f1_monitor_enable &&
            expect_bus_free &&
            scl_in &&
            !sda_in;

        f2_qualifies =
            f2_monitor_enable &&
            waiting_for_scl_high &&
            !scl_drive_low &&
            !scl_in;

    end


    /*
     * ================================================================
     * Detection counters
     * ================================================================
     *
     * Frozen threshold semantics:
     *
     *   LIMIT = N
     *
     *   qualifying samples 1 through N-1 -> no detection
     *   qualifying sample N             -> detection
     *
     * Qualification loss or detector disable resets the associated
     * persistence counter.
     *
     * F2 has classification priority. Although normal F1/F2 electrical
     * qualifiers are mutually exclusive because F1 requires SCL HIGH
     * and F2 requires SCL LOW, the explicit priority keeps the RTL
     * aligned with the frozen architecture.
     */
    always_ff @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            f1_count        <= '0;
            f2_count        <= '0;

            f1_fired        <= 1'b0;
            f2_fired        <= 1'b0;

            f1_detect_pulse <= 1'b0;
            f2_detect_pulse <= 1'b0;

        end
        else begin

            f1_detect_pulse <= 1'b0;
            f2_detect_pulse <= 1'b0;


            /*
             * --------------------------------------------------------
             * F2 detector
             * --------------------------------------------------------
             */
            if (f2_qualifies) begin

                if (!f2_fired) begin

                    if (f2_count == F2_LAST_COUNT) begin

                        f2_detect_pulse <= 1'b1;
                        f2_fired        <= 1'b1;

                    end
                    else begin

                        f2_count <= f2_count + 1'b1;

                    end

                end

            end
            else begin

                f2_count <= '0;
                f2_fired <= 1'b0;

            end


            /*
             * --------------------------------------------------------
             * F1 detector
             * --------------------------------------------------------
             *
             * Suppress/reset F1 whenever F2 qualification is active.
             */
            if (f2_qualifies) begin

                f1_count <= '0;
                f1_fired <= 1'b0;

            end
            else if (f1_qualifies) begin

                if (!f1_fired) begin

                    if (f1_count == F1_LAST_COUNT) begin

                        f1_detect_pulse <= 1'b1;
                        f1_fired        <= 1'b1;

                    end
                    else begin

                        f1_count <= f1_count + 1'b1;

                    end

                end

            end
            else begin

                f1_count <= '0;
                f1_fired <= 1'b0;

            end

        end

    end


    /*
     * ================================================================
     * Parameter sanity
     * ================================================================
     */
    initial begin

        if (SDA_STUCK_LIMIT_CYCLES < 1) begin
            $fatal(
                1,
                "SDA_STUCK_LIMIT_CYCLES must be >= 1"
            );
        end

        if (SCL_STALL_LIMIT_CYCLES < 1) begin
            $fatal(
                1,
                "SCL_STALL_LIMIT_CYCLES must be >= 1"
            );
        end

    end

endmodule