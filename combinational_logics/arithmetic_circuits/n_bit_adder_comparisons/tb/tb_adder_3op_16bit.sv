`timescale 1ns/1ps

module tb_adder_3op_16bit;

    logic [15:0] A, B, C;
    logic        Cin;
    logic [16:0] S;

    logic [16:0] expected_S;

    int total_passed = 0;
    int total_failed = 0;

    int NUM_RANDOM_TESTS = 20;

    // Instantiate DUT
    rca_3op_16bit DUT (
        .A   (A),
        .B   (B),
        .C   (C),
        .Cin (Cin),
        .S   (S)
    );

    initial begin
        $display("🔷 Starting RCA 3-Operand 16-bit Testbench");

        // Directed test cases
        run_test(16'h0000, 16'h0000, 16'h0000, 1'b0);
        run_test(16'h0001, 16'h0001, 16'h0001, 1'b0);
        run_test(16'hFFFF, 16'h0000, 16'h0000, 1'b0);
        run_test(16'hFFFF, 16'hFFFF, 16'h0000, 1'b0);
        run_test(16'hFFFF, 16'hFFFF, 16'hFFFF, 1'b0);
        run_test(16'd12345, 16'd54321, 16'd11111, 1'b0);
        run_test(16'd40000, 16'd25535, 16'd1000, 1'b0);

        // // Randomized test cases
        // $display("🔷 Running %0d randomized test cases...", NUM_RANDOM_TESTS);
        // for (int i = 0; i < NUM_RANDOM_TESTS; i++) begin
        //     A   = $urandom_range(0, 16'hFFFF);
        //     B   = $urandom_range(0, 16'hFFFF);
        //     C   = $urandom_range(0, 16'hFFFF);
        //     Cin = $urandom_range(0, 1);

        //     #10; // wait for outputs to settle
        //     expected_S = A + B + C + Cin;
        //     compare($sformatf("Random Test %0d", i), expected_S, S);
        // end

        report();
        $display(" Testbench completed.");
        $finish;
    end

    // Task to run one directed test
    task automatic run_test(
        input logic [15:0] a_in,
        input logic [15:0] b_in,
        input logic [15:0] c_in,
        input logic        cin_in
    );
        begin
            A   = a_in;
            B   = b_in;
            C   = c_in;
            Cin = cin_in;
            #10; // Wait for outputs to settle

            expected_S = a_in + b_in + c_in + cin_in;

            compare("Directed Test", expected_S, S);
        end
    endtask

    // Task to compare expected and actual outputs
    task automatic compare(
        input string test_name,
        input logic [16:0] expected,
        input logic [16:0] actual
    );
        if (expected !== actual) begin
            $display("  ❌ FAIL: %s", test_name);
            $display("     Expected: %h (%0d)", expected, expected);
            $display("     Got     : %h (%0d)", actual, actual);
            $display("     Inputs  : A=%h (%0d), B=%h (%0d), C=%h (%0d), Cin=%b", 
                A, A, B, B, C, C, Cin);
            total_failed++;
        end else begin
            $display("  ✅ PASS: %s → Sum=%h (%0d) [A=%h (%0d), B=%h (%0d), C=%h (%0d), Cin=%b]", 
                test_name, actual, actual, A, A, B, B, C, C, Cin);
            total_passed++;
        end
    endtask

    // Task to print summary
    task automatic report();
        $display("-------------------------------------------------");
        $display("Test Summary: %0d passed, %0d failed", total_passed, total_failed);
        if (total_failed == 0)
            $display("  🎉 All tests passed successfully!");
        else
            $display("  ⚠️ Some tests failed. Please check the log.");
        $display("-------------------------------------------------");
    endtask

endmodule
