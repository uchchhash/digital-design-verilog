`timescale 1ns/1ps

module four_bit_multiplier (
    input  logic [3:0] A,
    input  logic [3:0] B,
    output logic [7:0] P
);

    // Partial products
    logic pp[3:0][3:0];

    // Generate all partial products
    genvar i, j;
    generate
        for (i = 0; i < 4; i++) begin
            for (j = 0; j < 4; j++) begin
                assign pp[i][j] = A[i] & B[j];
            end
        end
    endgenerate

    // Output bit 0
    assign P[0] = pp[0][0];

    // Output bit 1
    logic s1_0, c1_0;
    half_adder HA1_0 (.A(pp[0][1]), .B(pp[1][0]), .Sum(P[1]), .Carry(c1_0));

    // Output bit 2
    logic s2_0, c2_0, s2_1, c2_1;
    full_adder FA2_0 (.A(pp[0][2]), .B(pp[1][1]), .Cin(pp[2][0]), .Sum(s2_0), .Cout(c2_0));
    half_adder HA2_1 (.A(s2_0), .B(c1_0), .Sum(P[2]), .Carry(c2_1));

    // Output bit 3
    logic s3_0, c3_0, s3_1, c3_1, s3_2, c3_2;
    full_adder FA3_0 (.A(pp[0][3]), .B(pp[1][2]), .Cin(pp[2][1]), .Sum(s3_0), .Cout(c3_0));
    full_adder FA3_1 (.A(s3_0), .B(pp[3][0]), .Cin(c2_0), .Sum(s3_1), .Cout(c3_1));
    half_adder HA3_2 (.A(s3_1), .B(c2_1), .Sum(P[3]), .Carry(c3_2));

    // Output bit 4
    logic s4_0, c4_0, s4_1, c4_1, s4_2, c4_2;
    full_adder FA4_0 (.A(pp[1][3]), .B(pp[2][2]), .Cin(pp[3][1]), .Sum(s4_0), .Cout(c4_0));
    full_adder FA4_1 (.A(s4_0), .B(c3_0), .Cin(c3_1), .Sum(s4_1), .Cout(c4_1));
    half_adder HA4_2 (.A(s4_1), .B(c3_2), .Sum(P[4]), .Carry(c4_2));

    // Output bit 5
    logic s5_0, c5_0, s5_1, c5_1;
    full_adder FA5_0 (.A(pp[2][3]), .B(pp[3][2]), .Cin(c4_0), .Sum(s5_0), .Cout(c5_0));
    full_adder FA5_1 (.A(s5_0), .B(c4_1), .Cin(c4_2), .Sum(P[5]), .Cout(c5_1));

    // Output bit 6
    logic s6_0, c6_0;
    full_adder FA6_0 (.A(pp[3][3]), .B(c5_0), .Cin(c5_1), .Sum(P[6]), .Cout(c6_0));

    // Output bit 7
    assign P[7] = c6_0;

endmodule
