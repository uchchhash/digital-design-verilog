`timescale 1ns/1ps

module tb_alu_fixed_point;

    parameter INT_WIDTH  = 4;
    parameter FRAC_WIDTH = 4;
    parameter DATA_WIDTH = INT_WIDTH + FRAC_WIDTH + 1;

    logic signed [DATA_WIDTH-1:0] a, b;
    logic [1:0] op;
    logic signed [DATA_WIDTH-1:0] result;
    logic overflow, underflow;

    logic signed [DATA_WIDTH-1:0] expected_result;

    int total_passed = 0;
    int total_failed = 0;
    int NUM_RANDOM_TESTS = 1000;

    // Instantiate DUT
    alu_fixed_point #(
        .INT_WIDTH(INT_WIDTH),
        .FRAC_WIDTH(FRAC_WIDTH)
    ) DUT (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .overflow(overflow),
        .underflow(underflow)
    );

initial begin
    $display("Starting Fixed-Point ALU Testbench (Randomized)");

    // Run fixed vectors first (optional)
    test_case(8'sd16, 8'sd16);
    test_case(8'sd16, -8'sd8);
    test_case(8'sd32, 8'sd32);
    test_case(-8'sd16, 8'sd16);
    test_case(8'sd0, 8'sd8);

    // Run randomized tests
    for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
        logic signed [DATA_WIDTH-1:0] rand_a;
        logic signed [DATA_WIDTH-1:0] rand_b;

        // Generate random signed values within representable range
        rand_a = $urandom_range(-(1 << (DATA_WIDTH-1)), (1 << (DATA_WIDTH-1)) - 1);
        rand_b = $urandom_range(-(1 << (DATA_WIDTH-1)), (1 << (DATA_WIDTH-1)) - 1);

        test_case(rand_a, rand_b);
    end

    report();
    $display("Testbench completed.");
    $finish;
end


    task automatic test_case(
        input logic signed [DATA_WIDTH-1:0] in_a,
        input logic signed [DATA_WIDTH-1:0] in_b
    );
        for (int i = 0; i < 4; i++) begin
            a  = in_a;
            b  = in_b;
            op = i[1:0];
            #5;

            calculate_expected(a, b, op, expected_result);
            compare(op_name(op), expected_result, result);
        end
    endtask

    function string op_name(input logic [1:0] op_code);
        case (op_code)
            2'b00: op_name = "ADD";
            2'b01: op_name = "SUB";
            2'b10: op_name = "MUL";
            2'b11: op_name = "DIV";
            default: op_name = "UNK";
        endcase
    endfunction

 // Task to calculate expected output
task automatic calculate_expected(
    input  logic signed [DATA_WIDTH-1:0] a,
    input  logic signed [DATA_WIDTH-1:0] b,
    input  logic [1:0] op,
    output logic signed [DATA_WIDTH-1:0] expected
);
    logic signed [(2*DATA_WIDTH)-1:0] temp;
    logic signed [DATA_WIDTH-1:0] scaled;

    expected = '0;

    case (op)
        2'b00: expected = a + b; // ADD
        2'b01: expected = a - b; // SUB
        2'b10: begin
            // signed multiply into wide temp
            temp = a * b;
            // shift right with arithmetic shift
            scaled = temp >>> FRAC_WIDTH;
            expected = scaled;
        end
        2'b11: begin
            if (b != 0) begin
                // shift numerator left to preserve fraction before division
                temp = (a <<< FRAC_WIDTH) / b;
                expected = temp[DATA_WIDTH-1:0];
            end else begin
                expected = '0;
            end
        end
        default: expected = '0;
    endcase
endtask


    // Task to compare expected and actual outputs
    task automatic compare(
        input string operation,
        input logic signed [DATA_WIDTH-1:0] expected,
        input logic signed [DATA_WIDTH-1:0] actual
    );
        if (expected !== actual) begin
            $display("  Mismatch: %s: Expected=%0d, Got=%0d [a=%0d, b=%0d]", 
                      operation, expected, actual, a, b);
            total_failed++;
        end else begin
            $display("  Match: %s=%0d [a=%0d, b=%0d]", 
                      operation, actual, a, b);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display("  All tests passed successfully.");
        else
            $display("  Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
