`timescale 1ns/1ps

module i2c_master_baseline #(
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
    output logic       scl_drive_low
);

    /*
     * Baseline wrapper.
     *
     * The protocol implementation resides in i2c_master_core.
     *
     * Fault-management functionality is intentionally absent from this
     * wrapper. During S6, the fault-aware controller will reuse the same
     * i2c_master_core instance and add monitoring/recovery around it.
     */

    logic core_expect_bus_free;
    logic core_waiting_for_scl_high;
    logic core_transaction_active;

    i2c_master_core #(
        .SYS_CLK_HZ (SYS_CLK_HZ),
        .I2C_CLK_HZ (I2C_CLK_HZ)
    ) u_core (
        .clk                  (clk),
        .rst_n                (rst_n),

        .cmd_valid            (cmd_valid),
        .cmd_ready            (cmd_ready),
        .cmd_rw               (cmd_rw),
        .cmd_addr             (cmd_addr),
        .cmd_wdata            (cmd_wdata),

        .read_data            (read_data),
        .busy                 (busy),
        .done                 (done),
        .nack                 (nack),

        .sda_in               (sda_in),
        .scl_in               (scl_in),

        .sda_drive_low        (sda_drive_low),
        .scl_drive_low        (scl_drive_low),

        .fault_abort          (1'b0),

        .expect_bus_free      (core_expect_bus_free),
        .waiting_for_scl_high (core_waiting_for_scl_high),
        .transaction_active   (core_transaction_active)
    );

endmodule