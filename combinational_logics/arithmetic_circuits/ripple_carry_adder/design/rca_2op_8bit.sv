`timescale 1ns/1ps

// Module: rca_2op_8bit
// Description: This module implements an 8-bit Ripple Carry Adder (RCA).
//              It takes two 8-bit operands (A, B) and a single carry-in (Cin),
//              and produces a 9-bit sum (S). The 9th bit (S[8]) represents
//              the final carry-out (Cout) of the 8-bit addition.
//
// Inputs:
//   A    : logic [7:0] - The first 8-bit unsigned operand. A[0] is LSB, A[7] is MSB.
//   B    : logic [7:0] - The second 8-bit unsigned operand. B[0] is LSB, B[7] is MSB.
//   Cin  : logic       - The initial carry-in to the least significant bit (bit 0) addition.
//
// Outputs:
//   S    : logic [8:0] - The 9-bit result of the addition (A + B + Cin).
//                        S[7:0] represents the 8-bit sum, and S[8] represents the final carry-out.

module rca_2op_8bit (
    input  logic [7:0] A,
    input  logic [7:0] B,
    input  logic       Cin,
    output logic [8:0] S  // 9-bit output to accommodate the 8-bit sum and the final carry-out
);

    // Internal Wires:
    // 'carry' array is used to chain the carry-out from one full_adder stage
    // to the carry-in of the next more significant stage.
    // carry[0] is Cout from FA0, carry[1] is Cout from FA1, ..., carry[7] is Cout from FA7.
    logic [7:0] carry;

    // Instance 1: Full Adder for the Least Significant Bit (LSB - Bit 0)
    // This adder takes the external Cin for the entire 8-bit operation.
    full_adder FA0 (
        .A    (A[0]),         // Input bit A for position 0
        .B    (B[0]),         // Input bit B for position 0
        .Cin  (Cin),          // External carry-in to the RCA
        .Sum  (S[0]),         // Output sum bit for position 0
        .Cout (carry[0])      // Carry-out from position 0, feeds into FA1
    );

    // Generate Block: Instantiates the remaining Full Adders (Bit 1 to Bit 7)
    // This loop creates 7 more full_adder instances.
    genvar i; // Declare 'i' as a generate loop variable
    generate
        // Loop from bit position 1 up to (but not including) 8.
        // This covers FA1, FA2, ..., FA7.
        for (i = 1; i < 8; i++) begin : rca_stage
            // Each instance is named 'FA' with a unique suffix from the loop variable 'i'.
            full_adder FA (
                .A    (A[i]),         // Input bit A for current position 'i'
                .B    (B[i]),         // Input bit B for current position 'i'
                .Cin  (carry[i-1]),   // Carry-in is the carry-out from the PREVIOUS stage (i-1)
                .Sum  (S[i]),         // Output sum bit for current position 'i'
                .Cout (carry[i])      // Carry-out from current position 'i', feeds into the NEXT stage (i+1)
            );
        end
    endgenerate

    // Final Carry-Out Assignment:
    // The carry-out from the most significant bit (MSB) full adder (FA7)
    // represents the overall carry-out of the 8-bit addition.
    // This carry-out (carry[7]) is assigned to the MSB (S[8]) of the 9-bit output sum.
    assign S[8] = carry[7];

endmodule