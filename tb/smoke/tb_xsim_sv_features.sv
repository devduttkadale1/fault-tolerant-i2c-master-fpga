`timescale 1ns/1ps

module tb_xsim_sv_features;

    logic clk;
    logic rst_n;
    logic req;
    logic ack;

    int pass_count;
    int fail_count;

    typedef enum logic [1:0] {
        ST_IDLE = 2'b00,
        ST_WAIT = 2'b01,
        ST_DONE = 2'b10
    } state_t;

    state_t state;

    always #5 clk = ~clk;

    task automatic check_equal(
        input string test_name,
        input int actual,
        input int expected
    );
        if (actual == expected) begin
            $display("[PASS] %s", test_name);
            pass_count++;
        end
        else begin
            $error(
                "[FAIL] %s actual=%0d expected=%0d",
                test_name,
                actual,
                expected
            );
            fail_count++;
        end
    endtask

    property p_req_ack;
        @(posedge clk)
        disable iff (!rst_n)
        req |-> ##1 ack;
    endproperty

    a_req_ack:
        assert property (p_req_ack)
        else begin
            $error("[FAIL] A_REQ_ACK");
            fail_count++;
        end

    initial begin
        clk        = 1'b0;
        rst_n      = 1'b0;
        req        = 1'b0;
        ack        = 1'b0;
        state      = ST_IDLE;
        pass_count = 0;
        fail_count = 0;

        repeat (3) @(posedge clk);
        rst_n = 1'b1;

        check_equal("ENUM_IDLE", state, ST_IDLE);

        @(posedge clk);
        state = ST_WAIT;
        check_equal("ENUM_WAIT", state, ST_WAIT);

        req = 1'b1;

        @(posedge clk);
        req = 1'b0;
        ack = 1'b1;

        @(posedge clk);
        ack   = 1'b0;
        state = ST_DONE;

        check_equal("ENUM_DONE", state, ST_DONE);

        repeat (2) @(posedge clk);

        if (fail_count == 0) begin
            $display("");
            $display("====================================");
            $display("XSIM SYSTEMVERILOG SMOKE TEST : PASS");
            $display("PASS COUNT = %0d", pass_count);
            $display("FAIL COUNT = %0d", fail_count);
            $display("====================================");
        end
        else begin
            $fatal(
                1,
                "XSIM SYSTEMVERILOG SMOKE TEST FAILED: %0d errors",
                fail_count
            );
        end

        $finish;
    end

endmodule