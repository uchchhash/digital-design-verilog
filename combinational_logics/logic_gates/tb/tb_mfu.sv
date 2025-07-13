`timescale 1ns/1ps

module tb_mfu;

    logic       a, b;
    logic [2:0] sel;
    logic       y;

    logic       expected_y;
    int         total_passed = 0;
    int         total_failed = 0;

    // Instantiate DUT
    mfu DUT (
        .a   (a),
        .b   (b),
        .sel (sel),
        .y   (y)
    );

    initial begin
        $display("Starting MFU Testbench");

        // Loop through all input combinations
        for (int i = 0; i < 8; i++) begin
            sel = i;
            for (int j = 0; j < 4; j++) begin
                {a, b} = j;
                #10;
                calculate_expected(a, b, sel, expected_y);
                compare(expected_y, y);
            end
        end

        report();
        $display("Testbench completed.");
        $finish();
    end

    // Task to calculate expected output based on inputs
    task automatic calculate_expected(
        input  logic a,
        input  logic b,
        input  logic [2:0] sel,
        output logic expected_y
    );
        case (sel)
            3'b000: expected_y  = a & b;    // AND
            3'b001: expected_y  = a | b;    // OR
            3'b010: expected_y  = ~a;       // NOT (ignores b)
            3'b011: expected_y  = ~(a & b); // NAND
            3'b100: expected_y  = ~(a | b); // NOR
            3'b101: expected_y  = a ^ b;    // XOR
            3'b110: expected_y  = ~(a ^ b); // XNOR
            3'b111: expected_y  = 1'b0;     // Reserved
            default: expected_y = 1'b0;
        endcase
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(input logic expected_y, input logic actual_y);
        if (expected_y !== actual_y) begin
            $display(" Mismatch: Expected=%b, Got=%b [sel=%b, a=%b, b=%b]", expected_y, actual_y, sel, a, b);
            total_failed++;
        end else begin
            $display(" Match: Output=%b [sel=%b, a=%b, b=%b]", actual_y, sel, a, b);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display(" All tests passed successfully!");
        else
            $display(" Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
