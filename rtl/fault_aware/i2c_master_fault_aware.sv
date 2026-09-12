`timescale 1ns/1ps

module i2c_master_fault_aware #(
    parameter integer SYS_CLK_HZ             = 100_000_000,
    parameter integer I2C_CLK_HZ             = 100_000,
    parameter integer SDA_STUCK_LIMIT_CYCLES = 10_000,
    parameter integer SCL_STALL_LIMIT_CYCLES = 100_000
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

    output logic       fault_active,
    output logic [1:0] fault_code,
    output logic       recovery_active,
    output logic       recovery_failed
);


    /*
     * ================================================================
     * Common-core interface
     * ================================================================
     *
     * The protocol FSM remains entirely inside i2c_master_core.
     *
     * This wrapper only coordinates:
     *
     *     - command admission;
     *     - fault monitoring/recovery;
     *     - bus-drive ownership;
     *     - externally visible completion/status composition.
     */
    logic       core_cmd_valid;
    logic       core_cmd_ready;

    logic [7:0] core_read_data;
    logic       core_busy;
    logic       core_done;
    logic       core_nack;

    logic       core_sda_drive_low;
    logic       core_scl_drive_low;

    logic       core_expect_bus_free;
    logic       core_waiting_for_scl_high;
    logic       core_transaction_active;


    /*
     * ================================================================
     * Fault-manager interface
     * ================================================================
     */
    logic manager_cmd_accept;

    logic manager_fault_abort;

    logic manager_block_cmd_ready;
    logic manager_fault_busy_hold;
    logic manager_fault_done_pulse;

    logic manager_recovery_owns_bus;
    logic manager_recovery_sda_drive_low;
    logic manager_recovery_scl_drive_low;


    /*
     * ================================================================
     * Command admission
     * ================================================================
     *
     * A fault/recovery condition blocks new commands before they reach
     * the common protocol core.
     */
    assign core_cmd_valid =
        cmd_valid &&
        !manager_block_cmd_ready;


    /*
     * External readiness is the common-core readiness qualified by the
     * fault manager.
     */
    assign cmd_ready =
        core_cmd_ready &&
        !manager_block_cmd_ready;


    /*
     * Historical successful-fault status is cleared only when the
     * external command interface performs an accepted handshake.
     */
    assign manager_cmd_accept =
        cmd_valid &&
        cmd_ready;


    /*
     * ================================================================
     * External data/status composition
     * ================================================================
     */
    assign read_data =
        core_read_data;


    /*
     * During an F2 termination of an active transaction, the common
     * core is aborted immediately but externally visible busy remains
     * asserted through containment via manager_fault_busy_hold.
     */
    assign busy =
        core_busy ||
        manager_fault_busy_hold;


    /*
     * Normal transactions complete through core_done.
     *
     * An F2-aborted active transaction completes externally through the
     * manager's single-cycle fault_done_pulse after containment.
     *
     * Autonomous F1 recovery and F1->F2 reclassification do not invent
     * command-completion pulses.
     */
    assign done =
        core_done ||
        manager_fault_done_pulse;


    /*
     * NACK remains a normal protocol result owned by the common core.
     *
     * Fault termination is reported separately through fault_active and
     * fault_code.
     */
    assign nack =
        core_nack;


    /*
     * ================================================================
     * Open-drain bus ownership
     * ================================================================
     *
     * Exactly one controller owns the physical drive-low outputs.
     *
     * Normal operation:
     *
     *     manager_recovery_owns_bus = 0
     *     -> common core drives the bus.
     *
     * Recovery/containment:
     *
     *     manager_recovery_owns_bus = 1
     *     -> fault manager drives/releases the bus.
     *
     * Both paths preserve open-drain semantics: a logic 1 here means
     * actively pull LOW; a logic 0 means electrically release.
     */
    assign sda_drive_low =
        manager_recovery_owns_bus ?
        manager_recovery_sda_drive_low :
        core_sda_drive_low;


    assign scl_drive_low =
        manager_recovery_owns_bus ?
        manager_recovery_scl_drive_low :
        core_scl_drive_low;


    /*
     * ================================================================
     * Verified common protocol core
     * ================================================================
     */
    i2c_master_core #(
        .SYS_CLK_HZ (SYS_CLK_HZ),
        .I2C_CLK_HZ (I2C_CLK_HZ)
    ) u_core (
        .clk                  (clk),
        .rst_n                (rst_n),

        .cmd_valid            (core_cmd_valid),
        .cmd_ready            (core_cmd_ready),

        .cmd_rw               (cmd_rw),
        .cmd_addr             (cmd_addr),
        .cmd_wdata            (cmd_wdata),

        .read_data            (core_read_data),
        .busy                 (core_busy),
        .done                 (core_done),
        .nack                 (core_nack),

        .sda_in               (sda_in),
        .scl_in               (scl_in),

        .sda_drive_low        (core_sda_drive_low),
        .scl_drive_low        (core_scl_drive_low),

        .fault_abort          (manager_fault_abort),

        .expect_bus_free      (core_expect_bus_free),
        .waiting_for_scl_high (core_waiting_for_scl_high),
        .transaction_active   (core_transaction_active)
    );


    /*
     * ================================================================
     * Verified fault detector / recovery manager
     * ================================================================
     *
     * i2c_fault_manager internally instantiates the already-verified
     * i2c_fault_detector.
     */
    i2c_fault_manager #(
        .SYS_CLK_HZ              (SYS_CLK_HZ),
        .I2C_CLK_HZ              (I2C_CLK_HZ),
        .SDA_STUCK_LIMIT_CYCLES  (SDA_STUCK_LIMIT_CYCLES),
        .SCL_STALL_LIMIT_CYCLES  (SCL_STALL_LIMIT_CYCLES)
    ) u_fault_manager (
        .clk                     (clk),
        .rst_n                   (rst_n),

        .cmd_accept              (manager_cmd_accept),

        .core_expect_bus_free    (core_expect_bus_free),
        .core_waiting_for_scl_high (
            core_waiting_for_scl_high
        ),
        .core_transaction_active (
            core_transaction_active
        ),
        .core_scl_drive_low      (core_scl_drive_low),

        .sda_in                  (sda_in),
        .scl_in                  (scl_in),

        .fault_abort             (manager_fault_abort),

        .block_cmd_ready         (manager_block_cmd_ready),
        .fault_busy_hold         (manager_fault_busy_hold),
        .fault_done_pulse        (manager_fault_done_pulse),

        .recovery_owns_bus       (manager_recovery_owns_bus),
        .recovery_sda_drive_low  (
            manager_recovery_sda_drive_low
        ),
        .recovery_scl_drive_low  (
            manager_recovery_scl_drive_low
        ),

        .fault_active            (fault_active),
        .fault_code              (fault_code),
        .recovery_active         (recovery_active),
        .recovery_failed         (recovery_failed)
    );


endmodule