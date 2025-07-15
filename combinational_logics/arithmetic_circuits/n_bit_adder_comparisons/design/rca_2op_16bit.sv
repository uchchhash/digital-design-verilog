`timescale 1ns/1ps

// Module: rca_2op_16bit
// Description: This module implements a 16-bit Ripple Carry Adder (RCA) by
//              hierarchically instantiating two 8-bit Ripple Carry Adders (rca_2op_8bit).
//              It sums two 16-bit operands (A, B) and an initial carry-in (Cin),
//              producing a 17-bit sum (S). The 17th bit (S[16]) represents the
//              final carry-out of the 16-bit addition.
//
// Inputs:
//   A    : logic [15:0] - The first 16-bit unsigned operand. A[0] is LSB, A[15] is MSB.
//   B    : logic [15:0] - The second 16-bit unsigned operand. B[0] is LSB, B[15] is MSB.
//   Cin  : logic        - The initial carry-in to the least significant bit (bit 0) of the overall addition.
//
// Outputs:
//   S    : logic [16:0] - The 17-bit result of the addition (A + B + Cin).
//                         S[15:0] represents the 16-bit sum, and S[16] represents the final carry-out.
//

module rca_2op_16bit (
    input  logic [15:0] A,
    input  logic [15:0] B,
    input  logic        Cin,
    output logic [16:0] S  // 17-bit output (16-bit sum + 1-bit final carry-out)
);

    // Internal Wire:
    // 'carry' is a 1-bit scalar wire used to connect the carry-out from the
    // lower 8-bit RCA (RCA0) to the carry-in of the upper 8-bit RCA (RCA1).
    // This forms the ripple-carry chain between the two 8-bit blocks.
    logic carry;

    // Instance 1: Lower 8-bit RCA (RCA0)
    // This handles the addition of the least significant 8 bits (A[7:0] and B[7:0]).
    // It takes the external Cin of the 16-bit adder.
    // The '.S' port of 'rca_2op_8bit' is 9 bits wide ({Cout, Sum[7:0]}).
    // Here, we split its output:
    rca_2op_8bit RCA0 (
        .A   (A[7:0]),  // Connects the lower 8 bits of operand A
        .B   (B[7:0]),  // Connects the lower 8 bits of operand B
        .Cin (Cin),     // Connects the external initial carry-in
        .S   ({carry, S[7:0]}) // The 9th bit (Cout) of RCA0 goes to 'carry' wire.
                               // The lower 8 bits (Sum) of RCA0 go to S[7:0] of the final 16-bit sum.
    );

    // Instance 2: Upper 8-bit RCA (RCA1)
    // This handles the addition of the most significant 8 bits (A[15:8] and B[15:8]).
    // Its carry-in is the carry-out from the lower 8-bit RCA (RCA0).
    // The '.S' port of 'rca_2op_8bit' is 9 bits wide ({Cout, Sum[7:0]}).
    // Here, we connect its output to the remaining bits of the final 16-bit sum:
    rca_2op_8bit RCA1 (
        .A   (A[15:8]),      // Connects the upper 8 bits of operand A
        .B   (B[15:8]),      // Connects the upper 8 bits of operand B
        .Cin (carry),        // Connects the carry-out from RCA0 as its carry-in
        .S   ({S[16], S[15:8]}) // The 9th bit (Cout) of RCA1 is the final carry-out for the entire 16-bit sum, assigned to S[16].
                                // The lower 8 bits (Sum) of RCA1 go to S[15:8] of the final 16-bit sum.
    );

endmodule

