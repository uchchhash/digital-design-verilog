`timescale 1ns/1ps

module rca_2op_8bit (
    input  logic [7:0] A,
    input  logic [7:0] B,
    input  logic       Cin,
    output logic [8:0] S  // 9-bit output to accommodate carry-out
);

    // Use an unpacked array for carry signals for clarity
    logic carry [7:0];

    // Instantiate first full adder with external carry-in
    full_adder FA0 (
        .A    (A[0]),
        .B    (B[0]),
        .Cin  (Cin),
        .Sum  (S[0]),
        .Cout (carry[0])
    );

    // Generate the rest of the full adders, chaining carry signals
    genvar i;
    generate
        for (i = 1; i < 8; i++) begin : rca_stage
            full_adder FA (
                .A    (A[i]),
                .B    (B[i]),
                .Cin  (carry[i-1]),
                .Sum  (S[i]),
                .Cout (carry[i])
            );
        end
    endgenerate

    // Assign the last carry-out to the MSB of the sum
    assign S[8] = carry[7];

endmodule
